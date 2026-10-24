#!/usr/bin/env python3
"""Cria a VM Always Free na Oracle e publica web, Sidekiq e Redis."""

import json
import os
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "tmp" / "oci-host.json"
CLOUD_INIT = ROOT / "tmp" / "oci-cloud-init.yaml"
ENV_SOURCE = ROOT / ".env.fly"
OCI = Path.home() / "bin" / "oci"
PROFILE = "FINDU"
SSH_KEY = Path.home() / ".ssh" / "id_ed25519"
INSTANCE_NAME = "findu"
SHAPES = ((2, 12), (1, 6))


class OciError(RuntimeError):
    pass


def oci(args, region=None, check=True):
    cmd = [str(OCI), "--profile", PROFILE, "--auth", "security_token"]
    if region:
        cmd.extend(["--region", region])
    cmd.extend(args)
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        detail = (result.stderr or result.stdout or "").strip()
        raise OciError(detail[-2000:])
    if not result.stdout.strip():
        return {"data": []}
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return {"raw": result.stdout}


def config_value(key):
    path = Path.home() / ".oci" / "config"
    if not path.exists():
        return None
    profile = None
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            profile = stripped[1:-1]
            continue
        if profile == PROFILE and stripped.startswith(f"{key}="):
            return stripped.split("=", 1)[1].strip()
    return None


def require_auth():
    if not OCI.exists():
        raise SystemExit(f"CLI não encontrada em {OCI}")
    if not config_value("tenancy"):
        raise SystemExit(
            "A conta Oracle ainda não está autenticada nesta máquina.\n"
            "Crie a conta em https://signup.oraclecloud.com/ (Always Free) e rode:\n"
            f"  {OCI} session authenticate --no-browser --profile-name {PROFILE} "
            "--region sa-saopaulo-1 --tenancy-name NOME_DA_TENANCY\n"
            "Quando o navegador concluir o login, rode de novo:\n"
            "  python3 script/oci_host.py up"
        )


def home_region():
    data = oci(["iam", "region-subscription", "list"])["data"]
    for item in data:
        if item.get("is-home-region"):
            return item["region-name"]
    configured = config_value("region")
    if configured:
        return configured
    raise OciError("Não achei a home region da tenancy.")


def ensure_network(compartment, region):
    vcns = oci(
        ["network", "vcn", "list", "--compartment-id", compartment, "--display-name", "findu-vcn"],
        region=region,
    )["data"]
    if vcns:
        vcn = vcns[0]
    else:
        vcn = oci(
            [
                "network", "vcn", "create",
                "--compartment-id", compartment,
                "--cidr-block", "10.0.0.0/16",
                "--display-name", "findu-vcn",
                "--dns-label", "finduvcn",
                "--wait-for-state", "AVAILABLE",
            ],
            region=region,
        )["data"]

    igws = oci(
        ["network", "internet-gateway", "list", "--compartment-id", compartment, "--vcn-id", vcn["id"]],
        region=region,
    )["data"]
    igw = next((item for item in igws if item["display-name"] == "findu-igw"), None)
    if igw is None:
        igw = oci(
            [
                "network", "internet-gateway", "create",
                "--compartment-id", compartment,
                "--vcn-id", vcn["id"],
                "--is-enabled", "true",
                "--display-name", "findu-igw",
                "--wait-for-state", "AVAILABLE",
            ],
            region=region,
        )["data"]

    oci(
        [
            "network", "route-table", "update",
            "--rt-id", vcn["default-route-table-id"],
            "--force",
            "--route-rules",
            json.dumps([{
                "destination": "0.0.0.0/0",
                "destinationType": "CIDR_BLOCK",
                "networkEntityId": igw["id"],
            }]),
        ],
        region=region,
    )
    oci(
        [
            "network", "security-list", "update",
            "--security-list-id", vcn["default-security-list-id"],
            "--force",
            "--ingress-security-rules",
            json.dumps([
                rule(22, "0.0.0.0/0"),
                rule(80, "0.0.0.0/0"),
                rule(443, "0.0.0.0/0"),
            ]),
            "--egress-security-rules",
            json.dumps([{
                "protocol": "all",
                "destination": "0.0.0.0/0",
                "isStateless": False,
            }]),
        ],
        region=region,
    )

    subnets = oci(
        ["network", "subnet", "list", "--compartment-id", compartment, "--vcn-id", vcn["id"], "--display-name", "findu-subnet"],
        region=region,
    )["data"]
    if subnets:
        return subnets[0]["id"]
    subnet = oci(
        [
            "network", "subnet", "create",
            "--compartment-id", compartment,
            "--vcn-id", vcn["id"],
            "--cidr-block", "10.0.0.0/24",
            "--display-name", "findu-subnet",
            "--dns-label", "findusub",
            "--route-table-id", vcn["default-route-table-id"],
            "--security-list-ids", json.dumps([vcn["default-security-list-id"]]),
            "--prohibit-public-ip-on-vnic", "false",
            "--wait-for-state", "AVAILABLE",
        ],
        region=region,
    )["data"]
    return subnet["id"]


def rule(port, source):
    return {
        "protocol": "6",
        "source": source,
        "isStateless": False,
        "tcpOptions": {"destinationPortRange": {"min": port, "max": port}},
    }


def ubuntu_image_for(compartment, region, shape, arch):
    images = oci(
        [
            "compute", "image", "list",
            "--compartment-id", compartment,
            "--operating-system", "Canonical Ubuntu",
            "--operating-system-version", "22.04",
            "--shape", shape,
            "--sort-by", "TIMECREATED",
            "--sort-order", "DESC",
            "--limit", "40",
        ],
        region=region,
    )["data"]
    for image in images:
        name = image.get("display-name", "")
        if "Minimal" in name:
            continue
        is_arm = "aarch64" in name or "arm64" in name
        if arch == "aarch64" and is_arm:
            return image["id"]
        if arch != "aarch64" and not is_arm:
            return image["id"]
    if images:
        return images[0]["id"]
    raise OciError(f"Não achei imagem Ubuntu 22.04 para {shape}.")


def ubuntu_image(compartment, region):
    return ubuntu_image_for(compartment, region, "VM.Standard.A1.Flex", "aarch64")


def launch_micro(compartment, region, subnet_id, ad):
    image_id = ubuntu_image_for(compartment, region, "VM.Standard.E2.1.Micro", "x86_64")
    try:
        return oci(
            [
                "compute", "instance", "launch",
                "--compartment-id", compartment,
                "--availability-domain", ad,
                "--shape", "VM.Standard.E2.1.Micro",
                "--subnet-id", subnet_id,
                "--image-id", image_id,
                "--display-name", INSTANCE_NAME,
                "--assign-public-ip", "true",
                "--ssh-authorized-keys-file", str(SSH_KEY.with_suffix(".pub")),
                "--user-data-file", str(CLOUD_INIT),
                "--boot-volume-size-in-gbs", "50",
                "--wait-for-state", "RUNNING",
            ],
            region=region,
        )["data"]
    except OciError as error:
        if "capacity" in str(error).lower():
            raise OciError("San Jose está sem capacidade nas VMs Always Free agora.") from error
        raise


def write_cloud_init():
    CLOUD_INIT.parent.mkdir(parents=True, exist_ok=True)
    CLOUD_INIT.write_text(
        """#cloud-config
package_update: true
packages:
  - ca-certificates
  - curl
runcmd:
  - bash -lc 'fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile && grep -q /swapfile /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab'
  - bash -lc 'for i in 1 2 3 4 5; do curl -fsSL https://get.docker.com | sh && break; sleep 20; done'
  - systemctl enable --now docker
  - usermod -aG docker ubuntu
  - mkdir -p /opt/findu
  - chown ubuntu:ubuntu /opt/findu
  - iptables -I INPUT -p tcp --dport 80 -j ACCEPT
  - iptables -I INPUT -p tcp --dport 443 -j ACCEPT
  - bash -lc 'iptables-save > /etc/iptables/rules.v4 || true'
"""
    )


def find_instance(compartment, region):
    instances = oci(
        [
            "compute", "instance", "list",
            "--compartment-id", compartment,
            "--display-name", INSTANCE_NAME,
            "--lifecycle-state", "RUNNING",
        ],
        region=region,
    )["data"]
    return instances[0] if instances else None


def launch_instance(compartment, region, subnet_id, image_id):
    domains = oci(
        ["iam", "availability-domain", "list", "--compartment-id", compartment],
        region=region,
    )["data"]
    if not domains:
        raise OciError("Nenhum availability domain na home region.")
    last_error = "sem tentativa"
    for domain in domains:
        ad = domain["name"]
        shapes = () if os.environ.get("OCI_SKIP_A1") == "1" else SHAPES
        for ocpus, memory in shapes:
            print(f"Tentando {ad} com {ocpus} OCPU e {memory} GB...", flush=True)
            try:
                launched = oci(
                    [
                        "compute", "instance", "launch",
                        "--compartment-id", compartment,
                        "--availability-domain", ad,
                        "--shape", "VM.Standard.A1.Flex",
                        "--shape-config", json.dumps({"ocpus": ocpus, "memoryInGBs": memory}),
                        "--subnet-id", subnet_id,
                        "--image-id", image_id,
                        "--display-name", INSTANCE_NAME,
                        "--assign-public-ip", "true",
                        "--ssh-authorized-keys-file", str(SSH_KEY.with_suffix(".pub")),
                        "--user-data-file", str(CLOUD_INIT),
                        "--boot-volume-size-in-gbs", "50",
                        "--wait-for-state", "RUNNING",
                    ],
                    region=region,
                )["data"]
                return launched
            except OciError as error:
                last_error = str(error)
                if "capacity" not in last_error.lower():
                    raise
                print("Sem capacidade nesse tamanho. Próxima tentativa.", flush=True)
    if os.environ.get("OCI_SKIP_MICRO") == "1":
        raise OciError(last_error)
    print("Ampere sem capacidade. Tentando a VM Always Free pequena (1 GB).", flush=True)
    return launch_micro(compartment, region, subnet_id, domains[0]["name"])


def public_ip(instance_id, region):
    for _ in range(30):
        vnics = oci(["compute", "instance", "list-vnics", "--instance-id", instance_id], region=region)["data"]
        if vnics and vnics[0].get("public-ip"):
            return vnics[0]["public-ip"]
        time.sleep(5)
    raise OciError("A VM subiu sem IP público.")


def save_state(state):
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2) + "\n")


def load_state():
    if not STATE.exists():
        raise SystemExit("Nenhuma VM registrada. Rode: python3 script/oci_host.py up")
    return json.loads(STATE.read_text())


def provision():
    require_auth()
    if not SSH_KEY.with_suffix(".pub").exists():
        raise SystemExit(f"Chave SSH não encontrada: {SSH_KEY}.pub")
    compartment = config_value("tenancy")
    region = home_region()
    print(f"Home region: {region}", flush=True)
    existing = find_instance(compartment, region)
    if existing:
        ip = public_ip(existing["id"], region)
        state = {"instance_id": existing["id"], "region": region, "ip": ip, "host": f"{ip}.sslip.io"}
        save_state(state)
        print(f"VM já existe: {ip}", flush=True)
        return state

    write_cloud_init()
    subnet_id = ensure_network(compartment, region)
    image_id = ubuntu_image(compartment, region)
    instance = launch_instance(compartment, region, subnet_id, image_id)
    ip = public_ip(instance["id"], region)
    state = {"instance_id": instance["id"], "region": region, "ip": ip, "host": f"{ip}.sslip.io"}
    save_state(state)
    print(f"VM no ar: {ip}", flush=True)
    return state


def ssh_cmd(ip, remote, input_text=None, timeout=120):
    cmd = [
        "ssh",
        "-i", str(SSH_KEY),
        "-o", "StrictHostKeyChecking=accept-new",
        "-o", "ConnectTimeout=15",
        "-o", "ServerAliveInterval=30",
        f"ubuntu@{ip}",
        remote,
    ]
    return subprocess.run(cmd, input=input_text, text=True, timeout=timeout)


def wait_ssh(ip):
    for attempt in range(40):
        result = ssh_cmd(ip, "echo ok", timeout=30)
        if result.returncode == 0:
            return
        print(f"SSH ainda não responde ({attempt + 1}/40)", flush=True)
        time.sleep(10)
    raise SystemExit("Não conectei por SSH na VM.")


def build_env(host):
    if not ENV_SOURCE.exists():
        raise SystemExit(f"Arquivo de ambiente não encontrado: {ENV_SOURCE}")
    values = {}
    for raw in ENV_SOURCE.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key] = value
    values.update({
        "RAILS_ENV": "production",
        "RAILS_LOG_TO_STDOUT": "true",
        "RAILS_SERVE_STATIC_FILES": "true",
        "STORAGE_SERVICE": "supabase",
        "PORT": "8080",
        "REDIS_URL": "redis://redis:6379/0",
        "APP_HOST": host,
        "APP_URL": f"https://{host}",
    })
    return "".join(f"{key}={value}\n" for key, value in values.items())


def deploy(state=None):
    state = state or load_state()
    ip = state["ip"]
    host = state["host"]
    wait_ssh(ip)
    print("Esperando o cloud-init instalar o Docker...", flush=True)
    ready = ssh_cmd(ip, "cloud-init status --wait && sudo docker version", timeout=900)
    if ready.returncode != 0:
        raise SystemExit("O cloud-init não terminou com Docker instalado.")
    opened = ssh_cmd(
        ip,
        "sudo iptables -C INPUT -p tcp --dport 80 -j ACCEPT || sudo iptables -I INPUT -p tcp --dport 80 -j ACCEPT; "
        "sudo iptables -C INPUT -p tcp --dport 443 -j ACCEPT || sudo iptables -I INPUT -p tcp --dport 443 -j ACCEPT; "
        "sudo sh -c 'iptables-save > /etc/iptables/rules.v4'",
        timeout=60,
    )
    if opened.returncode != 0:
        raise SystemExit("Não abri as portas 80 e 443 na VM.")
    print("Enviando o código...", flush=True)
    rsync = subprocess.run(
        [
            "rsync", "-az", "--delete",
            "-e", f"ssh -i {SSH_KEY} -o StrictHostKeyChecking=accept-new",
            "--exclude", ".git",
            "--exclude", "tmp",
            "--exclude", "log",
            "--exclude", "storage",
            "--exclude", ".env",
            "--exclude", ".env.*",
            "--exclude", "spec",
            "--exclude", "docs",
            "--exclude", "coverage",
            f"{ROOT}/",
            f"ubuntu@{ip}:/opt/findu/",
        ],
        timeout=300,
    )
    if rsync.returncode != 0:
        raise SystemExit("rsync falhou.")
    written = ssh_cmd(
        ip,
        "umask 077 && cat > /opt/findu/.env.production && chmod 600 /opt/findu/.env.production",
        input_text=build_env(host),
        timeout=60,
    )
    if written.returncode != 0:
        raise SystemExit("Não gravei o ambiente na VM.")
    print("Build e subida dos containers. A primeira vez leva vários minutos.", flush=True)
    up = ssh_cmd(
        ip,
        "cd /opt/findu && sudo docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build",
        timeout=1800,
    )
    if up.returncode != 0:
        raise SystemExit("docker compose up falhou. Veja o log acima na VM.")
    url = f"https://{host}/health"
    for _ in range(24):
        try:
            with urllib.request.urlopen(url, timeout=15) as response:
                body = response.read().decode()
                if response.status == 200 and "ok" in body:
                    print(f"Health ok: {url}", flush=True)
                    print(f"API: https://{host}", flush=True)
                    return
        except Exception:
            time.sleep(10)
    raise SystemExit(f"Containers subiram, mas {url} ainda não respondeu.")


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "up"
    if action == "up":
        deploy(provision())
    elif action == "provision":
        provision()
    elif action == "deploy":
        deploy()
    else:
        raise SystemExit("Uso: python3 script/oci_host.py [up|provision|deploy]")


if __name__ == "__main__":
    try:
        main()
    except OciError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
