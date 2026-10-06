public with sharing class FefoService {
    public class Sugestao {
        @AuraEnabled public Id loteId;
        @AuraEnabled public String numeroLote;
        @AuraEnabled public Date validade;
        @AuraEnabled public Decimal saldo;
    }

    @AuraEnabled
    public static Sugestao sugerirLote(Id produtoId, Id posicaoId, Decimal quantidade) {
        Decimal minimo = quantidade == null ? 0 : quantidade;
        Date hoje = Date.today();
        List<Saldo_Estoque__c> candidatos = [
            SELECT Lote__c, Lote__r.Name, Lote__r.Data_Validade__c, Quantidade_Atual__c
            FROM Saldo_Estoque__c
            WHERE Posicao__c = :posicaoId
              AND Lote__r.Produto__c = :produtoId
              AND Quantidade_Atual__c > 0
              AND Quantidade_Atual__c >= :minimo
              AND (Lote__r.Data_Validade__c = NULL OR Lote__r.Data_Validade__c >= :hoje)
            ORDER BY Lote__r.Data_Validade__c ASC NULLS LAST, Lote__r.CreatedDate ASC
            LIMIT 1
        ];
        if (candidatos.isEmpty()) { return null; }

        Saldo_Estoque__c s = candidatos[0];
        Sugestao sugestao = new Sugestao();
        sugestao.loteId = s.Lote__c;
        sugestao.numeroLote = s.Lote__r.Name;
        sugestao.validade = s.Lote__r.Data_Validade__c;
        sugestao.saldo = s.Quantidade_Atual__c;
        return sugestao;
    }
}
