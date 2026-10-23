
import os
import json
import random
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone

SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_KEY = os.environ["SUPABASE_SERVICE_KEY"]
BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]


def supabase(tabela, parametros=None, dados=None):
    url = SUPABASE_URL + "/rest/v1/" + tabela

    if parametros:
        url += "?" + urllib.parse.urlencode(parametros)

    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": "Bearer " + SUPABASE_KEY,
        "Content-Type": "application/json",
        "Prefer": "return=representation",
    }

    metodo = "POST" if dados is not None else "GET"
    corpo = json.dumps(dados).encode("utf-8") if dados is not None else None

    req = urllib.request.Request(
        url, data=corpo, headers=headers, method=metodo
    )

    with urllib.request.urlopen(req, timeout=30) as resposta:
        conteudo = resposta.read()
        return json.loads(conteudo) if conteudo else []


def imagem_valida(url):
    if not url or not url.startswith(("https://", "http://")):
        return False

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0"}
        )

        with urllib.request.urlopen(req, timeout=15) as resposta:
            tipo = resposta.headers.get("Content-Type", "")
            if resposta.status != 200:
                return False
            if not tipo.lower().startswith("image/"):
                return False
            return bool(resposta.read(32))

    except Exception as erro:
        print(f"Imagem invalida: {erro}")
        return False


def enviar_telegram(texto, imagem):
    url = f"https://api.telegram.org/bot{BOT_TOKEN}/sendPhoto"

    corpo = json.dumps({
        "chat_id": CHAT_ID,
        "photo": imagem,
        "caption": texto[:1024],
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=corpo,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=30) as resposta:
        resultado = json.loads(resposta.read())

    if not resultado.get("ok"):
        raise RuntimeError("Telegram nao confirmou o envio da foto")

    return resultado["result"]["message_id"]


def criar_mensagem(produto):
    mensagem = f"🔥 {produto['name']}\n\n"

    if produto.get("price") is not None:
        preco = f"{float(produto['price']):,.2f}"
        preco = preco.replace(",", "X").replace(".", ",")
        preco = preco.replace("X", ".")
        mensagem += f"💰 R$ {preco}\n"

    mensagem += (
        f"🏬 {produto.get('store_name') or 'Loja parceira'}\n\n"
        f"🛒 Confira a oferta:\n{produto['affiliate_url']}\n\n"
        "Publicidade: podemos receber comissao pela compra."
    )

    return mensagem


def main():
    historico = supabase("telegram_publications", {
        "select": "product_id",
        "limit": "100000",
    })

    publicados = {str(p["product_id"]) for p in historico}

    produtos = supabase("products", {
        "select": "id,name,price,store_name,affiliate_url,image_url",
        "affiliate_url": "not.is.null",
        "image_url": "not.is.null",
        "limit": "1000",
    })

    disponiveis = [
        p for p in produtos
        if str(p["id"]) not in publicados
        and (p.get("affiliate_url") or "").startswith(
            ("https://", "http://")
        )
    ]

    random.shuffle(disponiveis)

    for produto in disponiveis[:50]:
        imagem = produto.get("image_url")

        if not imagem_valida(imagem):
            print(f"Pulando produto sem foto valida: {produto['id']}")
            continue

        mensagem = criar_mensagem(produto)

        try:
            mensagem_id = enviar_telegram(mensagem, imagem)
        except Exception as erro:
            print(f"Falha ao enviar produto {produto['id']}: {erro}")
            continue

        supabase("telegram_publications", dados={
            "product_id": produto["id"],
            "telegram_message_id": mensagem_id,
            "published_at": datetime.now(timezone.utc).isoformat(),
            "status": "published",
        })

        print(f"Produto publicado e registrado: {produto['id']}")
        return

    raise RuntimeError(
        "Nenhum produto com imagem valida foi publicado"
    )


if __name__ == "__main__":
    main()
