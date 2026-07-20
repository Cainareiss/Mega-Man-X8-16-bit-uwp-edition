# Lições do port Godot 3 para UWP/Xbox

Este documento registra o conhecimento obtido ao levar Mega Man X8 16-bit para o backend UWP/ANGLE do Godot 3. O objetivo é reutilizar o processo em futuros ports sem depender do histórico de uma conversa.

## Princípio principal

Um objeto transparente ou uma animação ausente nem sempre significa que o arquivo de imagem está faltando. No UWP, a textura pode estar carregada enquanto o shader, a animação de atlas ou o caminho de partículas da GPU falha. Antes de criar um efeito substituto, é necessário estudar a cena, o material e o bitmap originais.

## Causas e correções confirmadas

### Backend de renderização

O template UWP do Godot 3 renderiza por uma versão antiga do ANGLE/GLES2. O jogo original funcionava em GLES3, mas alguns shaders e `Particles2D` não produziam a mesma saída no Xbox.

A validação deve forçar GLES2 no PC e permitir ativar o modo de compatibilidade UWP por variável de ambiente. Isso reduz o ciclo entre diagnóstico e teste no console.

### Carregamento do Mega Buster

O efeito original não era um círculo desenhado. Ele usava `charge_1.png` e `charge_2.png`, duas folhas de 192×192 pixels divididas em atlas 4×4. Um único particle tocava os 16 quadros durante 0,3 segundo, reiniciava e recebia a cor do `ParticlesMaterial`:

- azul durante a carga inicial;
- amarelo no nível carregado;
- branco na supercarga.

O fallback fiel desenha as regiões do atlas original por CPU, preserva tempo, cor, posição e ordem visual e apenas oculta a saída incompatível da GPU.

### `Parent node is busy setting up children`

O autoload de compatibilidade recebe `node_added` enquanto o Godot ainda está montando `Player.tscn`. Adicionar o fallback imediatamente falha, mesmo que o objeto permaneça registrado em um dicionário. A inserção deve usar:

```gdscript
parent.call_deferred("add_child", fallback)
```

O teste precisa instanciar um `PackedScene` para reproduzir essa ordem; adicionar um nó avulso não detecta o problema.

### Explosões de inimigos e chefes

Uma rajada única fazia inimigos sumirem ou terminava antes da animação de morte. Inimigos grandes e chefes precisam de uma sequência que emita explosões durante todo o estado de destruição.

A taxa pode ser derivada de `amount / lifetime`. Textura, quantidade, raio de emissão, escala e duração devem vir das partículas originais. Inimigos pequenos continuam usando uma explosão curta e proporcional.

### Cachoeiras

A cachoeira original não deslocava o UV. A sensação de movimento vinha da troca de cores em `waterfall_palette.png` a 24 FPS. Um scroll vertical genérico inverteu o movimento. A correção preservou a textura estática e reproduziu a paleta original em um shader GLES2 conservador.

### Inicialização

O cache tentava aquecer 177 partículas e shaders antes da primeira tela. No UWP isso podia fechar o aplicativo. O modo de compatibilidade deve ignorar o aquecimento de partículas GPU e desativar caches de shader de cena, deixando os efeitos serem preparados quando necessários.

## Estratégia de diagnóstico

Registrar em `user://`:

- detecção de UWP/GLES2;
- materiais substituídos;
- transições de estado de carga e morte;
- criação adiada dos fallbacks;
- textura, dimensões do atlas, cor, lifetime, spread e taxa;
- valores `visible`, `emitting` e `active`.

Usar os recursos verdadeiros no validador. Neste projeto, a varredura final cobriu 98 cenas, 4.111 nós visuais e 13.618 texturas, sem avisos ou falhas. Erros de limpeza do ObjectDB depois de `quit()` devem ser separados de falhas ocorridas durante o teste.

## Exportação e instalação

1. Fixar a mesma versão do Godot e dos templates de exportação.
2. Exportar UWP x64.
3. Reempacotar e assinar no Windows.
4. Conferir `Name`, `Publisher`, `Version`, arquitetura e VCLibs no manifesto interno.
5. Confirmar que o thumbprint do `.cer` corresponde ao assinante do MSIX.
6. Incluir MSIX, certificado, dependências, README, licença e guia na release.
7. Instalar e abrir no PC antes do sideload no Xbox.

O erro `0x800B0109` no PC indica que o certificado autoassinado não foi confiado pelo provedor de implantação. Neste ambiente foi necessário importá-lo, com elevação, em `LocalMachine\Root` e `LocalMachine\TrustedPeople`. Uma VCLibs instalada em versão superior já atende ao requisito mínimo.

## Resultado de referência

A release v1.0.0.14 restaurou a animação original do Buster e preservou as correções de sprites, explosões, cachoeiras e inicialização. O teste no PC e no Xbox confirmou o port sem falhas visuais ou funcionais conhecidas; a próxima validação é uma campanha completa.

O README, a licença e os créditos originais devem permanecer preservados. Alysson da Paz continua identificado como desenvolvedor no manifesto do aplicativo.
