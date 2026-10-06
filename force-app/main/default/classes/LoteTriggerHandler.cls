public with sharing class LoteTriggerHandler extends TriggerHandler {
    protected override void beforeInsert() { validarDatas((List<Lote__c>) Trigger.new); }
    protected override void beforeUpdate() { validarDatas((List<Lote__c>) Trigger.new); }

    private void validarDatas(List<Lote__c> lotes) {
        for (Lote__c l : lotes) {
            if (l.Data_Fabricacao__c != null && l.Data_Validade__c != null
                && l.Data_Validade__c < l.Data_Fabricacao__c) {
                l.addError('A data de validade não pode ser anterior à data de fabricação.');
            }
        }
    }
}
