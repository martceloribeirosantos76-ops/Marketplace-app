
import os
import json
import random
import urllib.request
import urllib.parse
import urllib.error
from pathlib import Path

SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_KEY = os.environ["SUPABASE_KEY"]
BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
CHAT_ID = os.environ["TELEGRAM_CHAT_ID"]

HISTORICO = Path("scripts/telegram_historico.json")
LIMITE = 5


def requisicao(url, dados=None, headers=None):
    corpo = None
    if dados is not None:
        corpo = json.dumps(dados).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=corpo,
        headers=headers or {},
    )

    with urllib.request.urlopen(req, timeout=30) as resposta:
        return json.loads(resposta.read().decode("utf-8"))


def buscar_produtos():
    parametros = urllib.parse.urlencode({
        "select": "id,name,price,image_url,affiliate_url,store_name",
        "affiliate_url": "not.is.null",
        "limit": "1000",
    })

    url = f"{SUPABASE_URL}/rest/v1/products?{parametros}"

    return requisicao(url, headers={
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
    })


def carregar_historico():
    if HISTORICO.exists():
        return set(json.loads(HISTORICO.read_text()))
    return set()


def salvar_historico(historico):
    HISTORICO.parent.mkdir(parents=True, exist_ok=True)
    HISTORICO.write_text(
        json.dumps(sorted(historico), ensure_ascii=False, indent=2)
    )


def enviar_produto(produto):
    nome = produto.get("name") or "Oferta especial"
    preco = produto.get("price")
    link = produto["affiliate_url"]
    loja = produto.get("store_name") or "Loja parceira"

    mensagem = f"🔥 {nome}\n\n"

    if preco is not None:
        valor = f"{float(preco):,.2f}"
        valor = valor.replace(",", "X").replace(".", ",").replace("X", ".")
        mensagem += f"💰 R$ {valor}\n"

    mensagem += (
        f"🏬 {loja}\n\n"
        f"🛒 Confira a oferta:\n{link}\n\n"
        "📢 @PrecoNexoOfertas\n"
        "Publicidade | Podemos receber comissão pela compra."
    )

    api = f"https://api.telegram.org/bot{BOT_TOKEN}/"

    imagem = produto.get("image_url")
    if imagem and len(mensagem) <= 1024:
        try:
            requisicao(api + "sendPhoto", {
                "chat_id": CHAT_ID,
                "photo": imagem,
                "caption": mensagem,
            })
            return
        except (urllib.error.HTTPError, urllib.error.URLError) as erro:
            print(f"Imagem indisponível: {erro}")

    requisicao(api + "sendMessage", {
        "chat_id": CHAT_ID,
        "text": mensagem,
        "disable_web_page_preview": True,
    })


def main():
    produtos = buscar_produtos()

    produtos = [
        p for p in produtos
        if p.get("affiliate_url", "").startswith(("https://", "http://"))
    ]

    historico = carregar_historico()
    disponiveis = [
        p for p in produtos if str(p["id"]) not in historico
    ]

    if not disponiveis and produtos:
        historico.clear()
        disponiveis = produtos

    selecionados = random.sample(
        disponiveis, min(LIMITE, len(disponiveis))
    )

    for produto in selecionados:
        enviar_produto(produto)
        historico.add(str(produto["id"]))
        salvar_historico(historico)
        print(f"Publicado produto ID: {produto['id']}")

    print(f"Total publicado: {len(selecionados)}")


if __name__ == "__main__":
    main()
