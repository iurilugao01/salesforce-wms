public with sharing class SaldoEstoqueTriggerHandler extends TriggerHandler {
    private static final String MSG_DERIVADO =
        'O saldo é derivado das movimentações e não pode ser alterado diretamente.';

    protected override void beforeInsert() { bloquear((List<Saldo_Estoque__c>) Trigger.new); }
    protected override void beforeUpdate() { bloquear((List<Saldo_Estoque__c>) Trigger.new); }
    protected override void beforeDelete() { bloquear((List<Saldo_Estoque__c>) Trigger.old); }

    private void bloquear(List<Saldo_Estoque__c> saldos) {
        if (SaldoEstoqueService.estaAplicando()) { return; }
        for (Saldo_Estoque__c s : saldos) { s.addError(MSG_DERIVADO); }
    }
}
