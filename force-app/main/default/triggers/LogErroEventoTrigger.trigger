trigger LogErroEventoTrigger on Log_Erro_Evento__e (after insert) {
    new LogErroEventoTriggerHandler().run();
}
