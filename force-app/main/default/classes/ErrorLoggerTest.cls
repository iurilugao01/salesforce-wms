@IsTest
private class ErrorLoggerTest {
    @IsTest
    static void registraExcecaoComOrigemMensagemEStack() {
        try {
            throw new IllegalArgumentException('falha de teste');
        } catch (Exception e) {
            ErrorLogger.log(e, 'ErrorLoggerTest');
        }
        Test.getEventBus().deliver();
        List<Log_Erro__c> logs = [SELECT Origem__c, Mensagem__c, Stack_Trace__c FROM Log_Erro__c];
        Assert.areEqual(1, logs.size());
        Assert.areEqual('ErrorLoggerTest', logs[0].Origem__c);
        Assert.areEqual('falha de teste', logs[0].Mensagem__c);
        Assert.isNotNull(logs[0].Stack_Trace__c);
    }

    @IsTest
    static void logSobreviveAoRollbackDaTransacao() {
        Savepoint sp = Database.setSavepoint();
        ErrorLogger.log(new IllegalArgumentException('boom'), 'RollbackTest');
        Database.rollback(sp);
        Test.getEventBus().deliver();
        List<Log_Erro__c> logs = [SELECT Origem__c, Mensagem__c FROM Log_Erro__c];
        Assert.areEqual(1, logs.size(), 'o log não pode ser desfeito pelo rollback');
        Assert.areEqual('RollbackTest', logs[0].Origem__c);
        Assert.areEqual('boom', logs[0].Mensagem__c);
    }

    @IsTest
    static void naoLancaQuandoExcecaoEhNula() {
        ErrorLogger.log(null, 'ErrorLoggerTest');
        Assert.areEqual(0, [SELECT COUNT() FROM Log_Erro__c]);
    }
}
