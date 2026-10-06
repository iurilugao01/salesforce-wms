trigger LoteTrigger on Lote__c (before insert, before update) {
    new LoteTriggerHandler().run();
}
