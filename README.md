# MyShoes

Aplicativo Android offline desenvolvido para vendedores organizarem produtos, clientes e pedidos de calçados recebidos por WhatsApp.

O aplicativo funciona sem conexão com a internet e armazena os dados localmente utilizando SQLite.

## Funcionalidades atuais

### Cadastro de produtos

* Listagem de produtos cadastrados
* Pesquisa por marca ou modelo
* Cadastro e edição de produtos
* Exclusão com confirmação
* Validação de campos obrigatórios
* Valores formatados em moeda brasileira
* Definição de numeração mínima e máxima
* Armazenamento offline com SQLite

### Cadastro de clientes

* Listagem de clientes
* Cadastro e edição
* Exclusão com confirmação
* Pesquisa por nome ou telefone
* Telefone opcional
* Observações opcionais
* Armazenamento offline com SQLite

### Cadastro de pedidos

* Criação e edição de pedidos
* Seleção de cliente cadastrado
* Possibilidade de informar rapidamente o nome do cliente
* Inclusão de produto no pedido
* Pesquisa de produtos por marca ou modelo
* Seleção de produto por meio de um Bottom Sheet
* Exibição do produto selecionado em um cartão
* Possibilidade de trocar ou remover o produto
* Definição da numeração do calçado
* Controle de quantidade
* Valor unitário preenchido com base no produto
* Cálculo do valor total
* Observações opcionais
* Armazenamento offline com SQLite

## Campos do produto

* Marca
* Modelo
* Numeração mínima
* Numeração máxima
* Valor de custo
* Valor de venda, opcional
* Observações, opcional

O cadastro do produto não possui foto, prazo ou status.

## Campos do cliente

* Nome
* Telefone, opcional
* Observações, opcional

## Campos do pedido

* Cliente
* Produto
* Numeração
* Quantidade
* Valor unitário
* Valor total
* Observações, opcional

## Tecnologias utilizadas

* Flutter
* Dart
* SQLite
* Material Design

## Como executar

Certifique-se de que o Flutter SDK esteja instalado e configurado.

Na raiz do projeto, execute:

```bash
flutter pub get
dart run flutter_launcher_icons
flutter run
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

Para gerar uma versão de teste:

```bash
flutter build apk --debug
```

Para gerar uma versão de produção:

```bash
flutter build apk --release
```

O arquivo será criado em:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Git

```bash
git add .
git commit -m "feat: adiciona cadastro de clientes e pedidos offline"
git push
```
