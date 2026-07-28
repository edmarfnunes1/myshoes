# MyShoes

Aplicativo Android offline desenvolvido para vendedores de calçados realizarem o cadastro de produtos, gerenciamento de pedidos, controle financeiro e consolidação de pedidos para envio à fábrica.

Todos os dados são armazenados localmente utilizando SQLite, permitindo o funcionamento completo sem conexão com a internet.

---

# Principais funcionalidades

## 👟 Cadastro de tênis

- Cadastro completo de tênis
- Pesquisa por marca, modelo, ID e data
- Ordenação por data ou ordem alfabética
- Cadastro de valor de custo
- Cadastro de valor de venda
- Definição da numeração mínima e máxima
- Observações opcionais
- Exclusão com confirmação
- Validação de campos obrigatórios
- Armazenamento offline
- Miniatura da marca nos cards
- Suporte a galeria de fotos do produto
- Foto principal e múltiplas imagens
- Carrossel com visualização em tela cheia

---

## 🖼️ Galeria de fotos

Cada tênis pode possuir até cinco fotos.

Recursos:

- Seleção múltipla pela galeria
- Compressão automática
- Correção de orientação
- Miniaturas otimizadas
- Foto principal
- Reordenação
- Exclusão individual
- Visualização em tela cheia
- Zoom nas imagens

---

## 🏷️ Marcas com identidade visual

O aplicativo possui logos personalizadas para:

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

Caso não exista uma logo cadastrada, é utilizado automaticamente o ícone padrão do aplicativo.

---

## 📦 Pedidos

- Cadastro de clientes
- Importação da agenda do telefone
- Múltiplos itens por pedido
- Seleção de numeração
- Controle de quantidade
- Cor por item
- Com ou sem caixa
- Valor de venda
- Situação do pagamento
- Pagamento parcial
- Observações
- Cálculo automático dos totais
- Pesquisa por ID e data
- Ordenação por data ou nome do cliente

---

## 🏭 Produção

Os pedidos podem ser enviados para produção através da tela Fábrica.

Após enviados:

- cliente permanece bloqueado
- itens permanecem bloqueados
- produtos permanecem bloqueados
- quantidades permanecem bloqueadas
- cores permanecem bloqueadas
- caixa permanece bloqueada
- exclusão bloqueada

Permite alterar apenas:

- situação do pagamento
- valor pago
- observações financeiras

---

## 🏭 Consolidação para fábrica

- Geração automática de lotes
- Agrupamento inteligente
- Consolidação por marca
- Modelo
- Numeração
- Cor
- Com ou sem caixa
- Histórico de lotes
- Visualização detalhada
- Compartilhamento via WhatsApp
- Compartilhamento por texto
- Exportação em PDF

---

## 💰 Financeiro

Controle financeiro completo dos pedidos.

Resumo por período:

- Hoje
- Esta semana
- Este mês
- Mês passado
- Personalizado

Indicadores:

- Total vendido
- Total recebido
- Total pendente
- Custo dos tênis
- Custo das caixas
- Custo total
- Lucro

Cada pedido apresenta:

- Venda
- Recebido
- Saldo
- Custo dos tênis
- Custo das caixas
- Custo total
- Lucro

---

## ⚙️ Configurações

Tela preparada para futuras configurações da fábrica.

Atualmente disponível:

### Adicionais da fábrica

- Valor cobrado por caixa

O valor configurado é salvo junto ao pedido, preservando o histórico financeiro mesmo que a configuração seja alterada futuramente.

A estrutura foi preparada para suportar novos adicionais da fábrica em versões futuras.

---

## ℹ️ Sobre

A tela Sobre apresenta:

- versão automática do aplicativo
- informações do projeto
- principais funcionalidades
- funcionamento offline
- desenvolvedor
- localização

A versão é lida automaticamente do arquivo `pubspec.yaml`.

---

# Campos do cadastro de tênis

- Marca
- Modelo
- Numeração mínima
- Numeração máxima
- Valor de custo
- Valor de venda
- Observações
- Fotos

---

# Campos do pedido

- Cliente
- Telefone
- Tênis
- Cor
- Numeração
- Quantidade
- Com ou sem caixa
- Valor de venda
- Situação do pagamento
- Valor pago
- Observações

---

# Tecnologias utilizadas

- Flutter
- Dart
- SQLite
- Material Design

Principais pacotes:

- sqflite
- intl
- flutter_contacts
- share_plus
- image_picker
- image
- path_provider

---

# Identidade visual

- Fundo: `#F8F9FA`
- Cor principal: `#CCFF00`
- Cor escura: `#0D131D`
- Cards brancos
- Bordas arredondadas
- Logo oficial
- Ícone padrão para marcas sem logo

---

# Estrutura do projeto

```text
assets/
├── Icones/
├── images/

lib/
├── database/
├── models/
├── pages/
├── repositories/
├── services/
├── widgets/
└── theme/
```

---

# Executando o projeto

```bash
flutter pub get
flutter run
```

Selecionar dispositivo:

```bash
flutter devices
flutter run -d ID_DO_DISPOSITIVO
```

---

# Qualidade

Analisar projeto:

```bash
flutter analyze
```

Executar testes:

```bash
flutter test
```

---

# Gerar APK

Debug:

```bash
flutter build apk --debug
```

Release:

```bash
flutter build apk --release
```

APK:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# Gerar App Bundle

```bash
flutter build appbundle --release
```

Bundle:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

# Versão

A versão é controlada exclusivamente pelo arquivo:

```yaml
pubspec.yaml
```

Exemplo:

```yaml
version: 2.0.0+2
```

A tela **Sobre** utiliza automaticamente essa informação.

---

# Desenvolvido por

**Innova QaSolutions**

Campo Mourão - PR

© 2026 Innova QaSolutions