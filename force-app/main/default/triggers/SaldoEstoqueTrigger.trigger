trigger SaldoEstoqueTrigger on Saldo_Estoque__c (before insert, before update, before delete) {
    new SaldoEstoqueTriggerHandler().run();
}
