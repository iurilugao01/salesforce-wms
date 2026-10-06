# Salesforce WMS — Design (Recorte 1: Inventário + Estrutura de Armazém)

Data: 2026-10-06

## 1. Objetivo e contexto

Projeto de portfólio, construído com rigor de projeto real: um WMS (Warehouse Management System) nativo Salesforce, desenvolvido no org Developer Edition `dev-org` (EconoPRO, instância CAN96).

**Recorte 1 (este spec):** núcleo de inventário e estrutura de armazém, completo e apresentável. Fluxos futuros (recebimento/putaway, picking/expedição, contagem cíclica) ficam fora deste recorte e terão specs próprios.

**Critério de sucesso:** um usuário consegue cadastrar a estrutura de um depósito, produtos e lotes, registrar entradas, saídas e transferências com saldo sempre consistente, visualizar a ocupação do depósito e acompanhar alertas de validade e relatórios em um dashboard — tudo com papéis de acesso distintos e testes automatizados.

## 2. Decisões tomadas

| Tema | Decisão |
|---|---|
| Modelo de dados | Objetos 100% customizados (sem `Product2`) |
| Estrutura de armazém | Hierárquica: Depósito → Zona → Corredor → Posição |
| Rastreabilidade | Por lote, com data de fabricação e validade |
| Operações | Entrada, Saída e Transferência interna |
| Interface | App Lightning nativo + LWC customizados + Relatórios/Dashboard |
| Movimentações | Ledger imutável; saldo sempre derivado |
| Saída | Sugestão automática de lote por FEFO (usuário pode trocar) |
| Segurança | Permission Sets: `WMS_Operador` e `WMS_Gestor` |
| Automação Apex | Framework de Trigger Handler (classe base + handlers) |
| Desenvolvimento | Projeto SFDX em `salesforce-wms/`, deploy direto no `dev-org` (sem scratch orgs) |

## 3. Arquitetura

Camadas:
- **Dados:** objetos customizados (hierarquia de armazém, inventário, ledger).
- **Automação (Apex):** trigger framework + serviços que recalculam saldo, aplicam FEFO e validam regras.
- **Interface:** Lightning App com abas nativas + LWC para as telas operacionais.
- **Analytics:** relatórios e dashboard nativos.

Fluxo central:

```
Usuário registra Movimentacao_Estoque__c (Entrada/Saída/Transferência)
  → before insert: MovimentacaoValidator
  → after insert: MovimentacaoEstoqueTriggerHandler → SaldoEstoqueService
  → Saldo_Estoque__c criado/atualizado (derivado, nunca editado manualmente)
```

## 4. Modelo de dados

**Hierarquia de armazém**

| Objeto | Campos principais | Relacionamento |
|---|---|---|
| `Deposito__c` | Nome, Endereço, Ativo | — |
| `Zona__c` | Nome, Tipo (Recebimento/Armazenagem/Expedição) | Lookup → `Deposito__c` |
| `Corredor__c` | Nome/Código | Lookup → `Zona__c` |
| `Posicao__c` | Código (ex: "A1-03"), Capacidade Máxima, Ativa | Lookup → `Corredor__c` |

**Produto e inventário**

| Objeto | Campos principais | Relacionamento |
|---|---|---|
| `Produto__c` | SKU, Nome, Unidade de Medida, Estoque Mínimo | — |
| `Lote__c` | Número do Lote, Data de Fabricação, Data de Validade, Quantidade Recebida | Lookup → `Produto__c` |
| `Saldo_Estoque__c` | Quantidade Atual (derivada) | Lookup → `Lote__c`, Lookup → `Posicao__c` |

**Ledger**

| Objeto | Campos principais |
|---|---|
| `Movimentacao_Estoque__c` | Tipo (Entrada/Saída/Transferência), Lote, Posição de Origem (vazia em Entrada), Posição de Destino (vazia em Saída), Quantidade, Data/Hora, Usuário Responsável, Status |

**Suporte**

| Objeto | Função |
|---|---|
| `Log_Erro__c` | Registro de exceções inesperadas (observabilidade) |

Regras-chave:
- `Saldo_Estoque__c` é sempre derivado: somente leitura para todos via FLS; apenas o Apex o escreve.
- Unicidade do par Lote+Posição em `Saldo_Estoque__c` (campo External Id composto); a escrita é um upsert lógico via Apex.
- `Movimentacao_Estoque__c` é imutável: ninguém tem Edit/Delete. Correções são feitas por movimentação compensatória.
- `MovimentacaoValidator` (before insert) bloqueia saída/transferência com quantidade maior que o saldo disponível no lote/posição de origem; a checagem fica em Apex porque exige consulta a `Saldo_Estoque__c`, o que uma Validation Rule não faz.

## 5. Automação (Apex)

**Trigger framework**

`TriggerHandler` (classe abstrata) com `beforeInsert/afterInsert/beforeUpdate/afterUpdate/beforeDelete/afterDelete` e controle de recursão por flag estática. Um trigger por objeto, apenas delegando ao handler.

**Handlers:** `MovimentacaoEstoqueTriggerHandler`, `LoteTriggerHandler` (valida validade ≥ fabricação).

**Serviços**

| Classe | Responsabilidade |
|---|---|
| `SaldoEstoqueService` | Aplica uma movimentação ao saldo: decrementa a origem, incrementa o destino; transferência é atômica |
| `FefoService` | Dado Produto + Posição, retorna o lote de vencimento mais próximo com saldo suficiente; exposto ao LWC via `@AuraEnabled` |
| `MovimentacaoValidator` | Saldo suficiente, posição ativa, lote não vencido |

Tratamento de erros: validações de negócio usam `addError()` na própria movimentação; exceções inesperadas são registradas em `Log_Erro__c`. Todo código é bulkificado (sem SOQL/DML em loop; testado com 200 registros).

## 6. Interface

**App Lightning "WMS":** abas nativas para todos os objetos (Saldo em somente leitura), com list views e record pages organizadas.

**LWC**

| Componente | Função |
|---|---|
| `registrarMovimentacao` | Tela única de Entrada/Saída/Transferência: busca de produto, seleção de posição, sugestão FEFO, validação de saldo antes de salvar |
| `visaoDeposito` | Visão hierárquica Zona → Corredor → Posição com saldo e indicador de ocupação |
| `alertaValidade` | Lotes próximos do vencimento (janela configurável, padrão 30 dias) |

Os três ficam em uma App Page "Painel Operacional".

**Analytics:** relatórios "Saldo por Depósito/Zona", "Movimentações por período/tipo", "Lotes a vencer" e dashboard "WMS – Visão Geral".

## 7. Segurança

| Permission Set | Acesso |
|---|---|
| `WMS_Operador` | Cria/lê `Movimentacao_Estoque__c`; lê saldo, lote, produto e hierarquia de armazém; usa as três LWC |
| `WMS_Gestor` | Tudo do Operador + CRUD em depósito, zona, corredor, posição, produto e lote; relatórios, dashboard e leitura de `Log_Erro__c` |

Classes Apex expostas ao LWC usam `with sharing` e verificam permissão de objeto/campo.

## 8. Testes e qualidade

- Cobertura Apex ≥ 90%, com classes de teste por unidade e `TestDataFactory` (sem `SeeAllData`).
- Cenários: entrada cria saldo; saída decrementa; saída acima do saldo é bloqueada; transferência é atômica; FEFO escolhe o vencimento mais próximo; lote vencido é rejeitado; carga de 200 registros.
- Jest para as três LWC (renderização, Apex mockado, estados de erro).
- `run_code_analyzer` antes de cada deploy.

## 9. Estrutura do projeto e deploy

```
salesforce-wms/
├── sfdx-project.json
├── force-app/main/default/
│   ├── objects/ classes/ triggers/ lwc/ permissionsets/
│   ├── flexipages/ applications/ tabs/ reports/ dashboards/
├── README.md
└── docs/
```

Deploy incremental por camada (objetos → Apex → LWC → permission sets → analytics) contra o `dev-org`. O README documenta arquitetura, diagrama do modelo de dados e instalação.

## 10. Fora do escopo (recortes futuros)

Recebimento/putaway, picking e expedição, contagem cíclica, rastreio por número de série, integração com leitor de código de barras/mobile.
