import base64
import hashlib
import os
import socket
import struct
import threading

HOST = "127.0.0.1"
PORT = 8767
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

clients = set()
lock = threading.Lock()


def ws_frame(payload, opcode=0x1):
    data = payload.encode("utf-8", "replace") if isinstance(payload, str) else payload
    n = len(data)
    head = bytearray([0x80 | opcode])
    if n < 126:
        head.append(n)
    elif n < 65536:
        head.append(126)
        head += struct.pack("!H", n)
    else:
        head.append(127)
        head += struct.pack("!Q", n)
    return bytes(head) + data


def read_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf


def send_all(payload, exclude=None):
    frame = ws_frame(payload)
    with lock:
        targets = [c for c in clients if c is not exclude]
    dead = []
    for c in targets:
        try:
            c.sendall(frame)
        except Exception:
            dead.append(c)
    if dead:
        with lock:
            for c in dead:
                clients.discard(c)


def handle_ws(conn, request):
    key = ""
    for line in request.split("\r\n"):
        if line.lower().startswith("sec-websocket-key:"):
            key = line.split(":", 1)[1].strip()
    accept = base64.b64encode(hashlib.sha1((key + GUID).encode()).digest()).decode()
    conn.sendall(
        b"HTTP/1.1 101 Switching Protocols\r\n"
        b"Upgrade: websocket\r\n"
        b"Connection: Upgrade\r\n"
        b"Sec-WebSocket-Accept: " + accept.encode() + b"\r\n\r\n"
    )
    with lock:
        clients.add(conn)
    try:
        while True:
            head = read_exact(conn, 2)
            if not head:
                break
            opcode = head[0] & 0x0F
            masked = (head[1] & 0x80) != 0
            ln = head[1] & 0x7F
            if ln == 126:
                b = read_exact(conn, 2)
                if not b:
                    break
                ln = struct.unpack("!H", b)[0]
            elif ln == 127:
                b = read_exact(conn, 8)
                if not b:
                    break
                ln = struct.unpack("!Q", b)[0]
            mask = read_exact(conn, 4) if masked else None
            payload = read_exact(conn, ln)
            if payload is None:
                break
            if mask:
                payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
            if opcode == 0x1:
                text = payload.decode("utf-8", "replace")
                if text.startswith("ECHO:"):
                    try:
                        conn.sendall(ws_frame(text))
                    except Exception:
                        pass
                else:
                    send_all(text, exclude=conn)
            elif opcode == 0x8:
                conn.sendall(ws_frame(b"", 0x8))
                break
            elif opcode == 0x9:
                conn.sendall(ws_frame(payload, 0xA))
    except Exception:
        pass
    finally:
        with lock:
            clients.discard(conn)
        try:
            conn.close()
        except Exception:
            pass


def handle_http(conn, request):
    line = request.split("\r\n")[0] if request else ""
    parts = line.split(" ")
    path = parts[1] if len(parts) > 1 else "/"
    path = path.split("?")[0]
    rel = path.lstrip("/")
    full = os.path.normpath(os.path.join(ROOT, rel))
    if not full.startswith(ROOT):
        conn.sendall(b"HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\n\r\n")
        return
    if os.path.isfile(full):
        with open(full, "rb") as f:
            body = f.read()
        conn.sendall(
            b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: "
            + str(len(body)).encode()
            + b"\r\n\r\n"
            + body
        )
    else:
        conn.sendall(b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n")


def client(conn, addr):
    try:
        conn.settimeout(5)
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = conn.recv(4096)
            if not chunk:
                return
            data += chunk
        request = data.split(b"\r\n\r\n")[0].decode("utf-8", "replace")
        if "upgrade: websocket" in request.lower():
            conn.settimeout(None)
            handle_ws(conn, request)
        else:
            handle_http(conn, request)
    except Exception:
        pass
    finally:
        try:
            conn.close()
        except Exception:
            pass


def main():
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind((HOST, PORT))
    srv.listen(32)
    print(f"ws_server http+ws on {HOST}:{PORT} root={ROOT}", flush=True)
    while True:
        conn, addr = srv.accept()
        threading.Thread(target=client, args=(conn, addr), daemon=True).start()


if __name__ == "__main__":
    main()
