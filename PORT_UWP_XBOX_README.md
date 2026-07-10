# Port UWP / Xbox Series S — Notas desta sessão

Este pacote contém o projeto original (`Mega-Man-X8-16-bit-main/`) com as adições e alterações abaixo, feitas para iniciar o port para UWP/Xbox Series S (Dev Mode). **Nada disso foi testado em hardware real ou no editor Godot** — foi produzido por análise estática do código-fonte. Trate como ponto de partida, não como solução final.

## O que foi adicionado

- `export_presets.cfg`: novo preset `"UWP Xbox Series S"` (preset.3), com identidade de pacote, GUID de teste para sideload, e ícones referenciados.
- `uwp_assets/`: ícones placeholder em todos os tamanhos exigidos pelo UWP, gerados a partir do `iconx3.png` existente (192×192) — **ficam com qualidade limitada em tamanhos maiores**; recomenda-se substituir por arte em alta resolução antes de uma build final.
- `uwp_manifest_reference/Package.appxmanifest` + `uwp_manifest_reference/Assets/`: manifesto UWP de referência preenchido, para uso manual via Visual Studio caso o pacote gerado direto pelo Godot não funcione.
- `docs/Guia_de_Adaptacao_de_Codigo_para_Xbox_v2.md`: guia de código atualizado com o diagnóstico real do projeto (substitui a v1).
- `docs/Guia_de_Build_e_Configuracao_do_Manifesto_UWP_v2.md`: guia de build atualizado com bugs conhecidos do exportador UWP do Godot 3.x e como contorná-los (substitui a v1).

## O que foi alterado no código

- `Tools.gd`: nova função estática `is_console_platform()` / `is_uwp_platform()`, baseada em `OS.has_feature("UWP")` (mecanismo oficial de feature tags do Godot 3.x).
- `src/Options/Fullscreen.gd`: a opção de menu "Fullscreen" agora se oculta inteiramente em build UWP, em vez de chamar `OS.window_fullscreen` (que não faz sentido em console).
- `src/Options/Size.gd`: mesma lógica aplicada à opção de multiplicador de tamanho de janela (1x–10x), pelo mesmo motivo.
- `src/Options/Vsync.gd`: **não alterado** — vsync continua válido em UWP/Xbox, independente do modo de janela.
- Nenhum binding do `InputMap` foi alterado — a análise mostrou que os `button_index` já correspondem corretamente a um controle Xbox padrão (A/B/X/Y, LB/RB, D-Pad, Start). Veja a seção 1 do guia de adaptação de código para detalhes.

## O que precisa de validação manual (não pôde ser confirmado sem rodar o motor)

1. **Feature tag `OS.has_feature("UWP")`**: confirmar que de fato retorna `true` num build UWP real antes de confiar nela em qualquer lógica visível ao jogador.
2. **Comportamento do XInput em UWP**: testar se o stick esquerdo, D-Pad e gatilhos do controle do Xbox Series S são lidos sem ruído/drift pelo runtime UWP do Godot 3.5.
3. **Bug de subsystem em build Release**: aplicar o workaround do `EDITBIN` (guia de build, seção 1.1) somente se o crash de fato ocorrer na sua build.
4. **Instalação do `.appx`**: se o pacote gerado pelo Godot não instalar via sideload, usar o [`godot-appx-repackager`](https://github.com/panreyes/godot-appx-repackager) antes de qualquer outra tentativa.
5. **Ícones placeholder**: substituir por versões em alta resolução antes de qualquer build destinada a mostrar para outras pessoas.

## Lembrete de licenciamento

Este é um fangame gratuito e não-comercial, não afiliado à CAPCOM (ver `LICENSE.md` e aviso no README original). Mantenha essa natureza não-comercial em qualquer build distribuída.
