public inherited sharing class ErrorLogger {
    private static final Integer LIMITE = 32000;

    public static void log(Exception e, String origem) {
        if (e == null) { return; }
        try {
            insert new Log_Erro__c(
                Origem__c = origem,
                Mensagem__c = truncar(e.getMessage()),
                Stack_Trace__c = truncar(e.getStackTraceString())
            );
        } catch (Exception falhaAoLogar) {
            System.debug(LoggingLevel.ERROR, 'ErrorLogger falhou: ' + falhaAoLogar.getMessage());
        }
    }

    private static String truncar(String texto) {
        return texto == null ? null : texto.abbreviate(LIMITE);
    }
}
