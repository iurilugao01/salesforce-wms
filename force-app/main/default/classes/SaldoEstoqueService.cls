public inherited sharing class SaldoEstoqueService {
    public class SaldoInsuficienteException extends Exception {}

    private class Delta {
        Id loteId;
        Id posicaoId;
        Decimal valor = 0;

        Delta(Id loteId, Id posicaoId) {
            this.loteId = loteId;
            this.posicaoId = posicaoId;
        }
    }

    public static String chave(Id loteId, Id posicaoId) {
        return String.valueOf(loteId) + '-' + String.valueOf(posicaoId);
    }

    public static void aplicar(List<Movimentacao_Estoque__c> movimentacoes) {
        Map<String, Delta> deltas = new Map<String, Delta>();
        for (Movimentacao_Estoque__c m : movimentacoes) {
            if (m.Posicao_Origem__c != null) {
                somar(deltas, m.Lote__c, m.Posicao_Origem__c, -m.Quantidade__c);
            }
            if (m.Posicao_Destino__c != null) {
                somar(deltas, m.Lote__c, m.Posicao_Destino__c, m.Quantidade__c);
            }
        }
        if (deltas.isEmpty()) { return; }

        Map<String, Saldo_Estoque__c> existentes = new Map<String, Saldo_Estoque__c>();
        for (Saldo_Estoque__c s : [
            SELECT Id, Chave__c, Quantidade_Atual__c
            FROM Saldo_Estoque__c
            WHERE Chave__c IN :deltas.keySet()
            FOR UPDATE
        ]) {
            existentes.put(s.Chave__c, s);
        }

        List<Saldo_Estoque__c> gravar = new List<Saldo_Estoque__c>();
        for (String k : deltas.keySet()) {
            Delta d = deltas.get(k);
            Saldo_Estoque__c atual = existentes.get(k);
            Decimal base = (atual == null || atual.Quantidade_Atual__c == null) ? 0 : atual.Quantidade_Atual__c;
            Decimal novo = base + d.valor;
            if (novo < 0) {
                throw new SaldoInsuficienteException('Saldo insuficiente para aplicar a movimentação (' + k + ').');
            }
            gravar.add(new Saldo_Estoque__c(
                Chave__c = k, Lote__c = d.loteId, Posicao__c = d.posicaoId, Quantidade_Atual__c = novo
            ));
        }
        upsert gravar Saldo_Estoque__c.Chave__c;
    }

    private static void somar(Map<String, Delta> deltas, Id loteId, Id posicaoId, Decimal valor) {
        String k = chave(loteId, posicaoId);
        Delta d = deltas.get(k);
        if (d == null) {
            d = new Delta(loteId, posicaoId);
            deltas.put(k, d);
        }
        d.valor += valor;
    }
}
