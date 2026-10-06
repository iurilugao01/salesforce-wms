public inherited sharing class MovimentacaoValidator {
    public static void validar(List<Movimentacao_Estoque__c> movimentacoes) {
        List<Movimentacao_Estoque__c> candidatas = new List<Movimentacao_Estoque__c>();
        for (Movimentacao_Estoque__c m : movimentacoes) {
            if (validarEstrutura(m)) { candidatas.add(m); }
        }
        if (candidatas.isEmpty()) { return; }

        Set<Id> loteIds = new Set<Id>();
        Set<Id> posicaoIds = new Set<Id>();
        for (Movimentacao_Estoque__c m : candidatas) {
            loteIds.add(m.Lote__c);
            if (m.Posicao_Origem__c != null) { posicaoIds.add(m.Posicao_Origem__c); }
            if (m.Posicao_Destino__c != null) { posicaoIds.add(m.Posicao_Destino__c); }
        }
        Map<Id, Lote__c> lotes = new Map<Id, Lote__c>([
            SELECT Id, Data_Validade__c FROM Lote__c WHERE Id IN :loteIds WITH SYSTEM_MODE
        ]);
        Map<Id, Posicao__c> posicoes = new Map<Id, Posicao__c>([
            SELECT Id, Ativa__c FROM Posicao__c WHERE Id IN :posicaoIds WITH SYSTEM_MODE
        ]);

        Date hoje = Date.today();
        List<Movimentacao_Estoque__c> aprovadas = new List<Movimentacao_Estoque__c>();
        for (Movimentacao_Estoque__c m : candidatas) {
            Lote__c lote = lotes.get(m.Lote__c);
            if (lote == null) { rejeitar(m, 'Lote não encontrado.'); continue; }
            if (lote.Data_Validade__c != null && lote.Data_Validade__c < hoje) {
                rejeitar(m, 'O lote está vencido e não pode ser movimentado.');
                continue;
            }
            if (m.Posicao_Origem__c != null && !posicaoAtiva(posicoes, m.Posicao_Origem__c)) {
                rejeitar(m, 'A posição de origem está inativa ou não existe.');
                continue;
            }
            if (m.Posicao_Destino__c != null && !posicaoAtiva(posicoes, m.Posicao_Destino__c)) {
                rejeitar(m, 'A posição de destino está inativa ou não existe.');
                continue;
            }
            aprovadas.add(m);
        }
        validarSaldos(aprovadas);
    }

    private static Boolean validarEstrutura(Movimentacao_Estoque__c m) {
        if (m.Lote__c == null) { return rejeitar(m, 'O lote é obrigatório.'); }
        if (m.Quantidade__c == null || m.Quantidade__c <= 0) {
            return rejeitar(m, 'A quantidade deve ser maior que zero.');
        }
        Boolean temOrigem = m.Posicao_Origem__c != null;
        Boolean temDestino = m.Posicao_Destino__c != null;
        if (m.Tipo__c == MovimentacaoTipo.ENTRADA) {
            if (temOrigem) { return rejeitar(m, 'Entrada não deve ter posição de origem.'); }
            if (!temDestino) { return rejeitar(m, 'Entrada exige posição de destino.'); }
        } else if (m.Tipo__c == MovimentacaoTipo.SAIDA) {
            if (temDestino) { return rejeitar(m, 'Saída não deve ter posição de destino.'); }
            if (!temOrigem) { return rejeitar(m, 'Saída exige posição de origem.'); }
        } else if (m.Tipo__c == MovimentacaoTipo.TRANSFERENCIA) {
            if (!temOrigem) { return rejeitar(m, 'Transferência exige posição de origem.'); }
            if (!temDestino) { return rejeitar(m, 'Transferência exige posição de destino.'); }
            if (m.Posicao_Origem__c == m.Posicao_Destino__c) {
                return rejeitar(m, 'Na transferência, origem e destino devem ser diferentes.');
            }
        } else {
            return rejeitar(m, 'Tipo de movimentação inválido.');
        }
        return true;
    }

    private static void validarSaldos(List<Movimentacao_Estoque__c> aprovadas) {
        Set<String> chavesOrigem = new Set<String>();
        for (Movimentacao_Estoque__c m : aprovadas) {
            if (m.Posicao_Origem__c != null) {
                chavesOrigem.add(SaldoEstoqueService.chave(m.Lote__c, m.Posicao_Origem__c));
            }
        }
        if (chavesOrigem.isEmpty()) { return; }

        Map<String, Decimal> disponivel = new Map<String, Decimal>();
        for (Saldo_Estoque__c s : [
            SELECT Chave__c, Quantidade_Atual__c FROM Saldo_Estoque__c
            WHERE Chave__c IN :chavesOrigem WITH SYSTEM_MODE FOR UPDATE
        ]) {
            disponivel.put(s.Chave__c, s.Quantidade_Atual__c);
        }

        for (Movimentacao_Estoque__c m : aprovadas) {
            if (m.Posicao_Origem__c != null) {
                String origem = SaldoEstoqueService.chave(m.Lote__c, m.Posicao_Origem__c);
                Decimal saldo = disponivel.containsKey(origem) ? disponivel.get(origem) : 0;
                if (saldo < m.Quantidade__c) {
                    rejeitar(m, 'Saldo insuficiente na posição de origem. Disponível: ' + saldo + '.');
                    continue;
                }
                disponivel.put(origem, saldo - m.Quantidade__c);
            }
            if (m.Posicao_Destino__c != null) {
                String destino = SaldoEstoqueService.chave(m.Lote__c, m.Posicao_Destino__c);
                Decimal saldoDestino = disponivel.containsKey(destino) ? disponivel.get(destino) : 0;
                disponivel.put(destino, saldoDestino + m.Quantidade__c);
            }
        }
    }

    private static Boolean posicaoAtiva(Map<Id, Posicao__c> posicoes, Id posicaoId) {
        Posicao__c p = posicoes.get(posicaoId);
        return p != null && p.Ativa__c == true;
    }

    private static Boolean rejeitar(Movimentacao_Estoque__c m, String mensagem) {
        m.addError(mensagem);
        return false;
    }
}
