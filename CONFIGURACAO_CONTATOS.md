# Configuração da agenda de contatos

O formulário de pedidos usa o pacote `flutter_contacts` para abrir a agenda nativa do celular e preencher o nome e o telefone do cliente.

## 1. pubspec.yaml

Adicione em `dependencies`:

```yaml
flutter_contacts: ^2.3.0
```

Depois execute:

```bash
flutter pub get
```

## 2. Android

No arquivo `android/app/src/main/AndroidManifest.xml`, antes da tag `<application>`, adicione:

```xml
<uses-permission android:name="android.permission.READ_CONTACTS" />
```

## 3. iOS

No arquivo `ios/Runner/Info.plist`, adicione:

```xml
<key>NSContactsUsageDescription</key>
<string>O MyShoes usa seus contatos para preencher os dados do cliente no pedido.</string>
```

O contato selecionado apenas preenche o formulário. Nome e telefone continuam editáveis antes de salvar o pedido.
