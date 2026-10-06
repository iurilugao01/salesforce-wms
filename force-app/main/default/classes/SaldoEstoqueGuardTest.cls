@IsTest
private class SaldoEstoqueGuardTest {
    @IsTest
    static void insertUpdateEDeleteDiretosSaoRejeitadosMesmoParaAdmin() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('G1-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-G1');
        Lote__c lote = TestDataFactory.criarLote(prod.Id, 'LG-1', Date.today().addDays(30));
        TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, pos.Id, 10);
        Saldo_Estoque__c saldo = [SELECT Id, Quantidade_Atual__c FROM Saldo_Estoque__c WHERE Lote__c = :lote.Id];

        saldo.Quantidade_Atual__c = 999;
        Database.SaveResult upd = Database.update(saldo, false);
        Assert.isFalse(upd.isSuccess());
        Assert.isTrue(upd.getErrors()[0].getMessage().contains('derivado'));

        Database.DeleteResult del = Database.delete(saldo.Id, false);
        Assert.isFalse(del.isSuccess());
        Assert.isTrue(del.getErrors()[0].getMessage().contains('derivado'));

        Database.SaveResult ins = Database.insert(
            new Saldo_Estoque__c(Chave__c = 'manual', Lote__c = lote.Id, Posicao__c = pos.Id, Quantidade_Atual__c = 5),
            false
        );
        Assert.isFalse(ins.isSuccess());
        Assert.isTrue(ins.getErrors()[0].getMessage().contains('derivado'));

        Assert.areEqual(10, TestDataFactory.saldo(lote.Id, pos.Id), 'o saldo continua o derivado do ledger');
    }

    @IsTest
    static void movimentacoesContinuamAtualizandoOSaldo() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('G2-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-G2');
        Lote__c lote = TestDataFactory.criarLote(prod.Id, 'LG-2', Date.today().addDays(30));
        TestDataFactory.registrar(MovimentacaoTipo.ENTRADA, lote.Id, null, pos.Id, 10);
        TestDataFactory.registrar(MovimentacaoTipo.SAIDA, lote.Id, pos.Id, null, 4);
        Assert.areEqual(6, TestDataFactory.saldo(lote.Id, pos.Id));
    }
}
