@IsTest
private class FefoServiceTest {
    private static Posicao__c pos;
    private static Produto__c produto;

    private static void montar() {
        pos = TestDataFactory.criarPosicaoCompleta('F1-01');
        produto = TestDataFactory.criarProduto('SKU-F');
    }

    private static Lote__c lote(String numero, Date validade, Decimal saldo) {
        Lote__c l = TestDataFactory.criarLote(produto.Id, numero, validade);
        TestDataFactory.criarSaldo(l.Id, pos.Id, saldo);
        return l;
    }

    @IsTest
    static void sugereOLoteDeVencimentoMaisProximo() {
        montar();
        lote('L-LONGE', Date.today().addDays(90), 50);
        Lote__c perto = lote('L-PERTO', Date.today().addDays(10), 50);
        FefoService.Sugestao s = FefoService.sugerirLote(produto.Id, pos.Id, 10);
        Assert.areEqual(perto.Id, s.loteId);
        Assert.areEqual('L-PERTO', s.numeroLote);
        Assert.areEqual(Date.today().addDays(10), s.validade);
        Assert.areEqual(50, s.saldo);
    }

    @IsTest
    static void ignoraLoteMaisProximoSemSaldoSuficiente() {
        montar();
        lote('L-PERTO-POUCO', Date.today().addDays(5), 5);
        Lote__c proximo = lote('L-OK', Date.today().addDays(20), 30);
        FefoService.Sugestao s = FefoService.sugerirLote(produto.Id, pos.Id, 10);
        Assert.areEqual(proximo.Id, s.loteId);
    }

    @IsTest
    static void loteSemValidadeFicaPorUltimo() {
        montar();
        lote('L-SEM', null, 100);
        Lote__c comValidade = lote('L-COM', Date.today().addDays(400), 100);
        FefoService.Sugestao s = FefoService.sugerirLote(produto.Id, pos.Id, 1);
        Assert.areEqual(comValidade.Id, s.loteId);
    }

    @IsTest
    static void loteSemValidadeEElegivelQuandoEOUnico() {
        montar();
        Lote__c sem = lote('L-SEM', null, 100);
        FefoService.Sugestao s = FefoService.sugerirLote(produto.Id, pos.Id, 1);
        Assert.areEqual(sem.Id, s.loteId);
        Assert.isNull(s.validade);
    }

    @IsTest
    static void ignoraLoteVencido() {
        montar();
        lote('L-VENCIDO', Date.today().addDays(-2), 100);
        Lote__c valido = lote('L-VALIDO', Date.today().addDays(2), 100);
        Assert.areEqual(valido.Id, FefoService.sugerirLote(produto.Id, pos.Id, 1).loteId);
    }

    @IsTest
    static void retornaNuloSemEstoqueSuficienteOuEmOutraPosicaoOuProduto() {
        montar();
        Posicao__c outra = TestDataFactory.criarPosicaoCompleta('F1-02');
        Produto__c outroProduto = TestDataFactory.criarProduto('SKU-F2');
        lote('L-A', Date.today().addDays(10), 5);
        Lote__c deOutroProduto = TestDataFactory.criarLote(outroProduto.Id, 'L-B', Date.today().addDays(10));
        TestDataFactory.criarSaldo(deOutroProduto.Id, pos.Id, 500);

        Assert.isNull(FefoService.sugerirLote(produto.Id, pos.Id, 6), 'nenhum lote com saldo suficiente');
        Assert.isNull(FefoService.sugerirLote(produto.Id, outra.Id, 1), 'outra posição sem estoque');
    }

    @IsTest
    static void quantidadeNulaConsideraZero() {
        montar();
        Lote__c l = lote('L-Q', Date.today().addDays(10), 5);
        Assert.areEqual(l.Id, FefoService.sugerirLote(produto.Id, pos.Id, null).loteId);
    }
}
