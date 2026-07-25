# MyShoes

Aplicativo Android offline desenvolvido para vendedores de calçados organizarem produtos, pedidos e consolidações para fábrica.

O MyShoes funciona sem conexão com a internet e armazena os dados localmente no dispositivo utilizando SQLite.

## Funcionalidades atuais

### Produtos

- Listagem de produtos cadastrados
- Pesquisa por marca, modelo, ID e data
- Cadastro e edição de produtos
- Exclusão com confirmação
- Validação de campos obrigatórios
- Valores formatados em moeda brasileira
- Definição de numeração mínima e máxima
- Valor de venda opcional
- Observações opcionais
- Exibição da logo da marca no card do produto
- Fallback para o ícone padrão `tenis_neon4.png` quando não houver logo
- Armazenamento offline com SQLite

### Marcas com logo

O aplicativo possui suporte visual para as seguintes marcas:

- Nike
- Adidas
- Puma
- New Balance
- Vans
- Lacoste
- Oakley
- Converse
- Asics
- Fila
- Reebok
- Under Armour
- Mizuno
- Olympikus
- Skechers
- Jordan
- Vert (Veja)
- Timberland
- DC Shoes
- Balenciaga

As imagens das marcas ficam em:

```text
assets/Icones/
```

### Pedidos

- Criação e edição de pedidos
- Nome e telefone do cliente informados diretamente no pedido
- Importação de contato da agenda do dispositivo
- Inclusão de um ou mais produtos no pedido
- Pesquisa de produtos por marca ou modelo
- Seleção de numeração
- Informação de cor por item
- Controle de quantidade
- Opção com ou sem caixa
- Valor de venda
- Situação de pagamento: Pendente ou Pago
- Observações opcionais
- Cálculo dos totais
- Pesquisa por ID e data
- Ordenação por data e ordem alfabética
- Armazenamento offline com SQLite

### Fábrica

- Consolidação dos pedidos para envio à fábrica
- Agrupamento das informações em uma única mensagem
- Compartilhamento pelo WhatsApp
- Geração de PDF
- Geração de texto
- Exibição detalhada do lote
- Ações de compartilhamento disponíveis no final da página

### Sobre

A tela **Sobre** apresenta:

- Nome do aplicativo
- Versão
- Descrição
- Principais recursos
- Informação de funcionamento offline
- Desenvolvido por **Innova QaSolutions**
- Campo Mourão - PR

## Campos do produto

- Marca
- Modelo
- Numeração mínima
- Numeração máxima
- Valor de custo
- Valor de venda, opcional
- Observações, opcional

## Campos do pedido

- Cliente
- Telefone, opcional
- Produto
- Cor
- Numeração
- Quantidade
- Com ou sem caixa
- Valor de venda
- Situação do pagamento
- Observações, opcional

## Tecnologias utilizadas

- Flutter
- Dart
- SQLite
- Material Design
- `sqflite`
- `intl`
- `flutter_contacts`

## Identidade visual

- Fundo: `#F8F9FA`
- Cor principal: `#CCFF00`
- Cor escura: `#0D131D`
- Cards brancos com cantos arredondados
- Logo principal: `assets/images/myshoes_logo.png`
- Ícone padrão: `assets/images/tenis_neon4.png`

## Como executar

Certifique-se de que o Flutter SDK esteja instalado e configurado.

Na raiz do projeto, execute:

```bash
flutter pub get
flutter run
```

Para executar em um dispositivo específico:

```bash
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

## Verificações do projeto

Para analisar possíveis problemas no código:

```bash
flutter analyze
```

Para executar os testes automatizados:

```bash
flutter test
```

## Gerar APK

Versão de teste:

```bash
flutter build apk --debug
```

Versão de produção:

```bash
flutter build apk --release
```

O APK de produção será criado em:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Gerar App Bundle

Para publicação na Google Play:

```bash
flutter build appbundle --release
```

O arquivo será criado em:

```text
build/app/outputs/bundle/release/app-release.aab
```

## Estrutura principal

```text
assets/
├── Icones/
│   └── logos das marcas
└── images/
    ├── myshoes_logo.png
    └── tenis_neon4.png

lib/
├── pages/
├── screens/
├── models/
├── database/
└── widgets/
```

## Git

Exemplo de commit para esta versão:

```bash
git add .
git commit -m "feat: conclui primeira versão do MyShoes"
git push
```

## Versão

```text
1.0.0
```

## Desenvolvido por

**Innova QaSolutions**

Campo Mourão - PR

© 2026 Innova QaSolutions
