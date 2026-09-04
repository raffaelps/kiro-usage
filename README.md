# Kiro Usage para macOS

Um pequeno app nativo que exibe na barra de menus o consumo mensal e o limite de créditos do Kiro.

## Instalar

Baixe o `.dmg` mais recente em [Releases](https://github.com/raffaelps/kiro-usage/releases/latest), abra e arraste **Kiro Usage** para a pasta **Applications**. O app é assinado com Developer ID e notarizado pela Apple, então abre sem avisos do Gatekeeper.

Requisito: macOS 14 (Sonoma) ou mais recente.

## Compilar a partir do código

Requisitos: macOS 14 (Sonoma) ou mais recente, Xcode instalado e [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
chmod +x build-app.sh
./build-app.sh
open "build/Kiro Usage.app"
```

O `build-app.sh` gera o projeto Xcode (`KiroUsage.xcodeproj`, não versionado) a partir de `project.yml` e compila com `xcodebuild`, para que o app e o widget sejam assinados corretamente com o mesmo time de desenvolvedor. É preciso estar logado no Xcode (**Settings → Accounts**) com uma conta Apple Developer autorizada a assinar com o time configurado em `project.yml` (`DEVELOPMENT_TEAM`).

O texto da barra mostra `usado/limite`, acompanhado de `↓` quando o consumo está abaixo do ritmo proporcional do mês, `↑` quando está acima ou `=` quando está exatamente no limite do dia. Clique nele para ver créditos restantes, percentual consumido, plano, data de renovação e o consumo proporcional recomendado até o dia atual. O cálculo considera o dia atual inteiro e o ciclo mensal do Kiro em UTC. Os dados são atualizados a cada 5 minutos.

Também há um widget de Desktop (tamanho pequeno) com o mesmo resumo — adicione pelo botão direito no Desktop → **Editar Widgets** → "Kiro Usage". O widget só lê um snapshot compartilhado pelo app principal (via App Group); ele não acessa a rede nem as credenciais do Kiro diretamente, então precisa que o app principal esteja rodando e conectado para ter dados atualizados.

Na primeira execução, o app instala um `LaunchAgent` somente para o usuário atual, em `~/Library/LaunchAgents/dev.raffael.kiro-usage.plist`, apontando para o caminho de onde o app foi aberto naquela vez — por isso mova `Kiro Usage.app` para `/Applications` (ou `~/Applications`) antes da primeira execução. A opção **Iniciar automaticamente com o macOS** permite desativar ou reativar esse comportamento.

No menu "…" também dá para deixar só o ícone na barra de menus (sem o texto `usado/limite`) e configurar alertas nativos do macOS para um ou mais limites de consumo (50%/75%/90%/100%).

## Publicar uma release

Requer também [create-dmg](https://github.com/create-dmg/create-dmg) (`brew install create-dmg`), um certificado **Developer ID Application** e credenciais de notarização salvas no Keychain:

```bash
xcrun notarytool store-credentials "kiro-usage-notary" --apple-id "seu-apple-id" --team-id 2TMMUPY74C --password "senha-de-app-especifica"
./release.sh
```

O `release.sh` arquiva em Release, exporta assinado com Developer ID, notariza o app, cola o ticket, confere com o Gatekeeper e monta o `.dmg` estilizado (fundo em `Resources/dmg-background.png`, gerado por `scripts/make_dmg_background.swift`) em `build/`.

## Login e privacidade

O app lê a sessão já criada pelo Kiro em `~/.aws/sso/cache/kiro-auth-token.json` e o perfil ativo dentro de `~/Library/Application Support/Kiro`. O token é usado somente em memória para consultar o serviço do Kiro; ele não é copiado nem salvo pelo app.

O monitor tenta renovar automaticamente sessões compatíveis com AWS IAM Identity Center, Builder ID e login social. Se a renovação não for mais possível, clique em **Abrir Kiro**, faça login no aplicativo Kiro IDE e depois atualize o monitor. Estar conectado somente no site `app.kiro.dev` não é suficiente, pois o site e o IDE mantêm sessões separadas.

## Observação técnica

O Kiro não documenta uma API pública de uso para apps de terceiros. Esta versão usa o mesmo endpoint e os mesmos arquivos locais usados pelo aplicativo oficial instalado. Uma futura atualização do Kiro pode exigir um ajuste nesta integração.

## Licença

[MIT](LICENSE).
