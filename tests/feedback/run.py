import json
import os
from pathlib import Path
import subprocess
import socket
import threading
import tempfile

PROJECT = Path(__file__).resolve().parents[2]
ENGINE = os.environ.get("SUMMER_BIN", "/Applications/Summer.app/Contents/MacOS/Summer")


def engine_probe(script, environment, marker):
    result = subprocess.run([ENGINE, "--headless", "--path", str(PROJECT), "--script", script],
                            env=environment, capture_output=True, text=True, timeout=30)
    print(result.stdout)
    if result.returncode or marker not in result.stdout or "SCRIPT ERROR" in result.stderr:
        raise RuntimeError(result.stderr + result.stdout)


with tempfile.TemporaryDirectory(prefix="pf-", dir="/tmp") as directory:
    path = Path(directory)
    environment = os.environ.copy()
    environment["FEEDBACK_PACKETS_PATH"] = str(path / "packets.json")
    engine_probe("tests/feedback/feedback_probe.gd", environment, "failures=[]")
    packets = json.loads((path / "packets.json").read_text())
    assert len(packets) == 7
    captured = []
    errors = []
    listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    listener.settimeout(5)
    listener.bind(str(path / "game.sock"))
    os.chmod(path / "game.sock", 0o600)
    listener.listen(1)

    def receive():
        try:
            connection, _address = listener.accept()
            with connection:
                connection.settimeout(2)
                buffer = bytearray()
                while b"\n" not in buffer and len(buffer) <= 8192:
                    chunk = connection.recv(8193 - len(buffer))
                    if not chunk:
                        break
                    buffer.extend(chunk)
                assert len(buffer) <= 8193 and buffer.endswith(b"\n")
                captured.append(json.loads(buffer))
                while connection.recv(1024):
                    pass
        except Exception as error:
            errors.append(str(error))

    worker = threading.Thread(target=receive, daemon=True)
    worker.start()
    try:
        environment["SUMMER_FEEDBACK_SOCKET"] = str(path / "game.sock")
        engine_probe("tests/feedback/transport_probe.gd", environment, "FEEDBACK_SOCKET_OK")
        worker.join(timeout=3)
        assert not worker.is_alive() and not errors, errors
        assert captured == [packets["victory"]]
    finally:
        listener.close()
print("PASS: project contract, desktop capture mock, real local socket; no shared kit or MCU")
