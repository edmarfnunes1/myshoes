# MyShoes

Aplicativo Android offline para vendedores organizarem modelos e pedidos de calçados recebidos pelo WhatsApp.

## Entrega atual

Fluxo completo de cadastro de produtos:

- lista de produtos;
- pesquisa por marca ou modelo;
- cadastro e edição;
- exclusão com confirmação;
- armazenamento offline com SQLite;
- validação de campos obrigatórios;
- valores em moeda brasileira;
- numeração mínima e máxima;
- valor de venda e observações opcionais.

## Campos do produto

- Marca
- Modelo
- Numeração mínima
- Numeração máxima
- Valor de custo
- Valor de venda (opcional)
- Observações (opcional)

Não possui foto, prazo ou status do produto.

## Como executar

1. Instale o Flutter SDK.
2. Na raiz do projeto, execute:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## Git

```bash
git add .
git commit -m "feat: implementa cadastro de produtos offline"
git push
```
