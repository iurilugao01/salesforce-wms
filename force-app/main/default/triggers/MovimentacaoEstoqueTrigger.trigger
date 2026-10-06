trigger MovimentacaoEstoqueTrigger on Movimentacao_Estoque__c (
    before insert, before update, before delete, after insert
) {
    new MovimentacaoEstoqueTriggerHandler().run();
}
