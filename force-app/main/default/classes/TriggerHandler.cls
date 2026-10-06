public abstract class TriggerHandler {
    private static Set<String> bypassed = new Set<String>();
    private static Map<String, Integer> loopCounts = new Map<String, Integer>();

    private Integer maxLoopCount = -1;
    private final String handlerName;

    protected TriggerHandler() {
        String descricao = String.valueOf(this);
        this.handlerName = descricao.substring(0, descricao.indexOf(':'));
    }

    public void run() {
        dispatch(Trigger.operationType);
    }

    public void setMaxLoopCount(Integer max) {
        this.maxLoopCount = max;
    }

    public static void bypass(String handlerName) { bypassed.add(handlerName); }
    public static void clearBypass(String handlerName) { bypassed.remove(handlerName); }
    public static void clearAllBypasses() { bypassed.clear(); }
    public static void resetLoopCounts() { loopCounts.clear(); }

    @TestVisible
    private void dispatch(TriggerOperation operacao) {
        if (operacao == null || bypassed.contains(handlerName) || excedeuLimite(operacao)) {
            return;
        }
        switch on operacao {
            when BEFORE_INSERT { beforeInsert(); }
            when AFTER_INSERT { afterInsert(); }
            when BEFORE_UPDATE { beforeUpdate(); }
            when AFTER_UPDATE { afterUpdate(); }
            when BEFORE_DELETE { beforeDelete(); }
            when AFTER_DELETE { afterDelete(); }
            when AFTER_UNDELETE { afterUndelete(); }
        }
    }

    private Boolean excedeuLimite(TriggerOperation operacao) {
        if (maxLoopCount < 0) { return false; }
        String chave = handlerName + ':' + operacao;
        Integer execucoes = (loopCounts.containsKey(chave) ? loopCounts.get(chave) : 0) + 1;
        loopCounts.put(chave, execucoes);
        return execucoes > maxLoopCount;
    }

    protected virtual void beforeInsert() {}
    protected virtual void afterInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void afterUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}
}
