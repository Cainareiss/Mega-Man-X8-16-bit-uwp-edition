# Guia de Build e Configuração do Manifesto UWP para Xbox Series S — v2

**Atualizado com achados reais sobre bugs conhecidos do exportador UWP do Godot 3.x.** Este documento substitui a v1 e deve ser lido junto com o `Guia_de_Adaptacao_de_Codigo_para_Xbox_v2.md`.

## 0. O que já está pronto no repositório

- `export_presets.cfg` agora tem um preset **`"UWP Xbox Series S"`** (preset.3), com identidade de pacote, GUID de teste e ícones já referenciados.
- `uwp_manifest_reference/Package.appxmanifest`: manifesto de referência preenchido, para o caso de você montar o projeto UWP manualmente no Visual Studio em vez de usar o pacote gerado direto pelo Godot.
- `uwp_manifest_reference/Assets/`: ícones placeholder (gerados a partir do `iconx3.png` existente, redimensionados para os tamanhos exigidos pelo UWP: 44, 71, 150, 310, splash, store logo). **Esses ícones são provisórios** — ficam borrados em tamanhos maiores porque a fonte é só 192×192. Recomendamos gerar versões em alta resolução a partir da arte original antes de uma build final.

**Identidade usada no preset/manifesto (somente para sideload em Dev Mode):**
- Publisher: `CN=AlyssonDaPaz`
- Package Name: `AlyssonDaPaz.MegaManX816bit`
- GUID de teste: `6a145a6d-e1c7-4cfd-b58f-641c7d665436`

Esse GUID **não é válido para a Microsoft Store** — é só um identificador gerado localmente para permitir sideload em Dev Mode. Para publicação real, gere a identidade a partir do registro do app no Partner Center.

## 1. Bugs conhecidos do exportador UWP do Godot 3.x (importante ler antes de exportar)

Pesquisa confirmou que o exportador UWP do Godot 3.x **não está em estado totalmente estável**, mesmo na versão 3.5 usada neste projeto. Dois problemas específicos e documentados pela comunidade:

### 1.1. Build Release pode crashar na inicialização (bug de subsystem)

Builds **Release** exportados pelo Godot para UWP têm um bug de longa data relacionado ao uso do subsystem `WINDOWS` no executável, que causa crash na inicialização. O workaround documentado pela comunidade:

1. Após exportar, abra o `.appx`/pasta de saída e localize o executável (`MegaManX8UWP.exe`).
2. Use a ferramenta `EDITBIN` (parte do Visual Studio Build Tools) para forçar o subsystem `CONSOLE`:
   ```
   EDITBIN /subsystem:CONSOLE MegaManX8UWP.exe
   ```
3. Isso resolve o crash, mas abre uma janela de console visível ao iniciar o jogo. Para fechar essa janela automaticamente, é necessário um código auxiliar que chame `FreeConsole()` via uma DLL nativa — o plugin GDNative [`GodotXbox`](https://github.com/CreggHancock/GodotXbox) inclui uma classe `ConsoleCloser` pronta para isso (adicionar como autoload).

**Para builds Debug** esse problema não costuma ocorrer — então, para os primeiros testes em Dev Mode, prefira manter `Debug` antes de investir tempo no workaround do EDITBIN.

### 1.2. Pacote `.appx` exportado pode precisar de repacote e assinatura manual

Há relatos consistentes na comunidade de que o `.appx` gerado diretamente pelo exportador do Godot 3.x **não instala corretamente** sem ser repacotado e assinado. Existe uma ferramenta de terceiros para automatizar isso:

- [`godot-appx-repackager`](https://github.com/panreyes/godot-appx-repackager) — script PowerShell que baixa as ferramentas necessárias (MSBuild Tools, DLLs Angle), cria um certificado autoassinado, e repacota/assina o `.appx`.

**Fluxo recomendado**, nessa ordem:
1. Exporte do Godot usando o preset `"UWP Xbox Series S"`.
2. Se o `.appx` resultante não instalar via sideload (erro de pacote inválido/não assinado), use o `godot-appx-repackager` antes de tentar a rota manual via Visual Studio descrita na seção 2.

## 2. Exportação do Projeto Godot para UWP

1. **Abra o projeto no Godot Engine 3.5** (mesma versão usada no desenvolvimento — não use 3.x diferente, pode haver incompatibilidade de export templates).
2. Vá em `Projeto` → `Exportar...`.
3. Selecione o preset **`UWP Xbox Series S`** (já presente no `export_presets.cfg`).
4. Confirme que os **Export Templates UWP 3.5** estão instalados (`Editor` → `Manage Export Templates`). Caso não estejam, faça o download pela própria interface do Godot.
5. **Modo de Depuração**: mantenha `Debug` para os primeiros testes (ver seção 1.1 sobre o bug de Release).
6. Clique em `Exportar Projeto`. O caminho de saída já está configurado para `../UWP_Export/MegaManX8UWP/` relativo à raiz do projeto.

## 3. Configuração e Empacotamento no Visual Studio (rota manual/fallback)

Use esta seção somente se o pacote gerado direto pelo Godot não instalar via sideload, mesmo após o repackager.

1. **Crie um Novo Projeto UWP Vazio no Visual Studio**:
   - `Arquivo` → `Novo` → `Projeto...` → `Aplicativo em Branco (Universal Windows)`.
   - Nome: `MegaManX8UWP`.
2. **Copie os arquivos exportados do Godot** para a raiz do projeto UWP criado.
3. **Substitua o `Package.appxmanifest` gerado** pelo arquivo de referência em `uwp_manifest_reference/Package.appxmanifest` deste repositório (ajustando o caminho dos assets para `Assets\` dentro do projeto VS), ou copie os valores de identidade/capacidades manualmente para o manifesto que o Visual Studio já criou.
4. **Empacote a Aplicação**:
   - Botão direito no projeto → `Publicar` → `Criar Pacotes de Aplicativos...`.
   - Escolha `Sideloading`.
   - Selecione `Não, eu preciso de um novo certificado de teste` e siga as instruções.
   - Arquitetura `x64`.
   - Clique em `Criar`.

## 4. Implantação no Xbox Series S (Dev Mode)

1. **Ative o Modo de Desenvolvedor** no Xbox Series S via o app `Xbox Dev Mode Activation` (taxa única da Microsoft).
2. **Acesse o Portal de Dispositivos** pelo IP exibido na tela do Xbox em Dev Mode.
3. **Instale o certificado de teste** (`.cer`) gerado no passo de empacotamento, na seção de gerenciamento de certificados do portal.
4. **Instale o pacote** (`.appx`/`.msix`) na seção de gerenciamento de aplicativos.
5. **Execute o jogo** pela lista de aplicativos instalados.

## 5. Solução de Problemas Comuns (atualizado)

| Problema | Causa provável | Solução |
| :--- | :--- | :--- |
| Falha na instalação do pacote | Certificado não instalado, ou `.appx` não repacotado corretamente | Reinstale o `.cer`; se persistir, use o `godot-appx-repackager` antes de tentar instalar |
| Jogo crasha ao abrir (só em build Release) | Bug de subsystem WINDOWS do exportador Godot 3.x | Aplicar `EDITBIN /subsystem:CONSOLE` (seção 1.1), ou testar primeiro em Debug |
| Jogo não inicia, sem crash visível | `Ponto de Entrada`/`Executable` no manifesto não corresponde ao nome real do `.exe` exportado | Confirme que `Executable="MegaManX8UWP.exe"` bate exatamente com o nome gerado pelo Godot |
| Controle Xbox não responde ou responde errado | Driver XInput em UWP pode se comportar diferente do Windows Desktop | Sem solução de código antecipada — testar no console é o único jeito de confirmar; o InputMap do jogo já está correto para Xbox (ver guia de adaptação de código, seção 1) |
| Item de menu "Fullscreen" ou "Window Size" aparecendo no Xbox | Build antiga sem a checagem `Tools.is_console_platform()` | Recompile a partir da versão atualizada do código (`Fullscreen.gd`, `Size.gd`) |

Este guia será atualizado conforme testes reais no hardware revelem novos problemas — vários pontos aqui (detecção de feature tag UWP, comportamento do XInput) **dependem de validação empírica** que não pôde ser feita neste momento por falta de acesso a um Xbox físico ou ao editor Godot durante a elaboração deste guia.
