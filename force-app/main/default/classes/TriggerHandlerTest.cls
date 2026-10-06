@IsTest
private class TriggerHandlerTest {
    private class StubHandler extends TriggerHandler {
        public List<String> chamadas = new List<String>();
        protected override void beforeInsert() { chamadas.add('beforeInsert'); }
        protected override void afterInsert() { chamadas.add('afterInsert'); }
        protected override void beforeUpdate() { chamadas.add('beforeUpdate'); }
        protected override void afterUpdate() { chamadas.add('afterUpdate'); }
        protected override void beforeDelete() { chamadas.add('beforeDelete'); }
        protected override void afterDelete() { chamadas.add('afterDelete'); }
        protected override void afterUndelete() { chamadas.add('afterUndelete'); }
    }

    @IsTest
    static void roteiaCadaOperacaoParaOHook() {
        StubHandler h = new StubHandler();
        h.dispatch(TriggerOperation.BEFORE_INSERT);
        h.dispatch(TriggerOperation.AFTER_INSERT);
        h.dispatch(TriggerOperation.BEFORE_UPDATE);
        h.dispatch(TriggerOperation.AFTER_UPDATE);
        h.dispatch(TriggerOperation.BEFORE_DELETE);
        h.dispatch(TriggerOperation.AFTER_DELETE);
        h.dispatch(TriggerOperation.AFTER_UNDELETE);
        Assert.areEqual(
            new List<String>{ 'beforeInsert', 'afterInsert', 'beforeUpdate', 'afterUpdate', 'beforeDelete', 'afterDelete', 'afterUndelete' },
            h.chamadas
        );
    }

    @IsTest
    static void bypassImpedeExecucaoEClearBypassRestaura() {
        StubHandler h = new StubHandler();
        String nome = String.valueOf(h).substring(0, String.valueOf(h).indexOf(':'));
        TriggerHandler.bypass(nome);
        h.dispatch(TriggerOperation.BEFORE_INSERT);
        Assert.isTrue(h.chamadas.isEmpty(), 'handler em bypass não deve executar');
        TriggerHandler.clearBypass(nome);
        h.dispatch(TriggerOperation.BEFORE_INSERT);
        Assert.areEqual(1, h.chamadas.size());
    }

    @IsTest
    static void maxLoopCountInterrompeRecursao() {
        TriggerHandler.resetLoopCounts();
        StubHandler h = new StubHandler();
        h.setMaxLoopCount(2);
        h.dispatch(TriggerOperation.AFTER_UPDATE);
        h.dispatch(TriggerOperation.AFTER_UPDATE);
        h.dispatch(TriggerOperation.AFTER_UPDATE);
        Assert.areEqual(2, h.chamadas.size(), 'a terceira execução deve ser ignorada');
    }

    @IsTest
    static void semLimiteExecutaSempre() {
        TriggerHandler.resetLoopCounts();
        StubHandler h = new StubHandler();
        for (Integer i = 0; i < 5; i++) { h.dispatch(TriggerOperation.AFTER_INSERT); }
        Assert.areEqual(5, h.chamadas.size());
    }
}
