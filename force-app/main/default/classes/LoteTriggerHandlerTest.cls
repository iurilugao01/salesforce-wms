@IsTest
private class LoteTriggerHandlerTest {
    @IsTest
    static void validadeAnteriorAFabricacaoERejeitada() {
        Produto__c prod = TestDataFactory.criarProduto('SKU-L');
        Lote__c l = new Lote__c(
            Name = 'L-X', Produto__c = prod.Id,
            Data_Fabricacao__c = Date.today(), Data_Validade__c = Date.today().addDays(-1)
        );
        Database.SaveResult r = Database.insert(l, false);
        Assert.isFalse(r.isSuccess());
        Assert.isTrue(r.getErrors()[0].getMessage().contains('anterior à data de fabricação'));
    }

    @IsTest
    static void validadeIgualOuPosteriorEAceitaEDatasNulasTambem() {
        Produto__c prod = TestDataFactory.criarProduto('SKU-L2');
        List<Lote__c> lotes = new List<Lote__c>{
            new Lote__c(Name = 'L-IGUAL', Produto__c = prod.Id, Data_Fabricacao__c = Date.today(), Data_Validade__c = Date.today()),
            new Lote__c(Name = 'L-FUTURO', Produto__c = prod.Id, Data_Fabricacao__c = Date.today(), Data_Validade__c = Date.today().addDays(30)),
            new Lote__c(Name = 'L-SEM-VALIDADE', Produto__c = prod.Id, Data_Fabricacao__c = Date.today()),
            new Lote__c(Name = 'L-SEM-DATAS', Produto__c = prod.Id)
        };
        for (Database.SaveResult r : Database.insert(lotes, false)) {
            Assert.isTrue(r.isSuccess());
        }
    }

    @IsTest
    static void updateParaValidadeInvalidaERejeitado() {
        Produto__c prod = TestDataFactory.criarProduto('SKU-L3');
        Lote__c l = TestDataFactory.criarLote(prod.Id, 'L-UPD', Date.today().addDays(30));
        l.Data_Validade__c = l.Data_Fabricacao__c.addDays(-1);
        Database.SaveResult r = Database.update(l, false);
        Assert.isFalse(r.isSuccess());
    }
}
