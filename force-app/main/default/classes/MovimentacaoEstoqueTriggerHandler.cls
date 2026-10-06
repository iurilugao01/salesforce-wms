public with sharing class MovimentacaoEstoqueTriggerHandler extends TriggerHandler {
    private static final String MSG_IMUTAVEL =
        'Movimentações são imutáveis. Registre uma movimentação compensatória.';

    protected override void beforeInsert() {
        List<Movimentacao_Estoque__c> novas = (List<Movimentacao_Estoque__c>) Trigger.new;
        for (Movimentacao_Estoque__c m : novas) {
            if (m.Data_Hora__c == null) { m.Data_Hora__c = System.now(); }
            if (m.Usuario_Responsavel__c == null) { m.Usuario_Responsavel__c = UserInfo.getUserId(); }
        }
        MovimentacaoValidator.validar(novas);
    }

    protected override void afterInsert() {
        SaldoEstoqueService.aplicar((List<Movimentacao_Estoque__c>) Trigger.new);
    }

    protected override void beforeUpdate() {
        for (Movimentacao_Estoque__c m : (List<Movimentacao_Estoque__c>) Trigger.new) {
            m.addError(MSG_IMUTAVEL);
        }
    }

    protected override void beforeDelete() {
        for (Movimentacao_Estoque__c m : (List<Movimentacao_Estoque__c>) Trigger.old) {
            m.addError(MSG_IMUTAVEL);
        }
    }
}
