# Automação de favoritos pelo HandlivPanel

## Escopo e autorização

A configuração pertence a uma conta e a um ativo da lista de favoritos. Instalar ou atualizar o painel **não ativa a automação**: o EA usa `InpAllowAutomation=false` por padrão, e as regras novas do site começam desativadas. O operador precisa liberar o EA e confirmar cada regra no site. A implementação e os testes não autorizam ordens reais de verificação.

## Configuração

- Selecione a conta na aba MT5.
- Informe o **símbolo exato da corretora**, incluindo sufixos. O símbolo de análise não é automaticamente convertido para um símbolo negociável.
- Escolha Compra, Venda ou Compra e venda.
- Informe o volume em lotes, com até duas casas decimais. O EA rejeita volume fora do mínimo, máximo ou passo da corretora; não aumenta o lote silenciosamente.
- Configure Stop e Alvo por multiplicadores de ATR. Valores iniciais: Stop 2 × ATR e Alvo 3 × ATR. ATR de 14 períodos, H1, último candle fechado, calculado com os dados da **corretora**, não com o preço exibido na análise web.
- Salve desativada para revisar antes de confirmar a ativação. A confirmação autoriza operações reais.

## Gatilho de entrada

O motor usa as recomendações canônicas da análise de ativos: `COMPRA FORTE` ou `VENDA FORTE`, respeitando a direção configurada. Sentimento isolado de notícias não é o gatilho. Análises ausentes, inválidas ou vencidas bloqueiam a entrada.

Na primeira observação válida após ativar, o sinal atual é registrado como referência e **nenhuma ordem é aberta imediatamente**. Um sinal forte persistente não gera entradas repetidas. É necessária uma observação válida não forte antes de armar uma nova entrada. Falha de análise não equivale a sinal neutro e não rearma a regra.

Não deve ser aberta uma segunda posição desta automação no mesmo símbolo da conta. Posições e ordens de outros robôs não são encerradas. Em conta MT5 netting, uma posição existente no símbolo impede a entrada automática para evitar alterar exposição de terceiros.

## Proteção e rastreabilidade

Stop e alvo são enviados na solicitação inicial de abertura. Se ATR, cotação, parâmetros, distância mínima ou níveis da corretora não puderem ser validados, a entrada é rejeitada. Não há tentativa de abrir sem SL/TP.

Comandos automáticos têm validade curta, identificação própria e proteção contra repetição. `pending` ou `sent` não significam uma execução confirmada: acompanhe a resposta do EA e o histórico do terminal. Desativar revoga comandos automáticos ainda pendentes; não fecha posições já abertas nem desfaz uma ordem já entregue ao terminal.

O EA atualizado precisa anunciar as capacidades de automação e proteção, estar liberado pelo operador e enviar estatísticas recentes. **Cada consulta de comandos também precisa anunciar essas capacidades e a liberação local**: estatísticas de um EA novo não autorizam outro painel antigo na mesma conta a consumir a ordem automática. O servidor não deve enviar comandos automáticos a um painel antigo sem esses guardas.

## Limites da verificação

Testes de lógica, mocks locais de API, compilação e build web não provam execução numa corretora. Validação operacional deve ocorrer numa **conta demo explicitamente autorizada**, incluindo compra, venda, lote, SL/TP, repetição, reinício, expiração e desativação. Não iniciar terminais reais nem instalar binários na VPS apenas para testar o recurso.

Stop e alvo não garantem o preço de execução em gaps ou baixa liquidez, e uma recomendação forte não garante retorno.
