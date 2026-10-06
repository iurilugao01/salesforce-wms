public without sharing class LogErroEventoTriggerHandler extends TriggerHandler {
    protected override void afterInsert() {
        List<Log_Erro__c> logs = new List<Log_Erro__c>();
        for (Log_Erro_Evento__e evento : (List<Log_Erro_Evento__e>) Trigger.new) {
            logs.add(new Log_Erro__c(
                Origem__c = evento.Origem__c,
                Mensagem__c = evento.Mensagem__c,
                Stack_Trace__c = evento.Stack_Trace__c
            ));
        }
        insert as system logs;
    }
}
