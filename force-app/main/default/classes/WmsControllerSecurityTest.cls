@IsTest
private class WmsControllerSecurityTest {
    private static User criarUsuario(Boolean comOperador) {
        Id perfilId = [
            SELECT Id FROM Profile
            WHERE UserType = 'Standard' AND PermissionsModifyAllData = false AND PermissionsViewAllData = false
            LIMIT 1
        ].Id;
        String sufixo = String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User u = new User(
            Alias = 'w' + sufixo.left(6),
            Email = 'wms' + sufixo + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Operador',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = perfilId,
            TimeZoneSidKey = 'America/Sao_Paulo',
            Username = 'wms' + sufixo + '@example.com.wmstest'
        );
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert u;
            if (comOperador) {
                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'WMS_Operador'];
                insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id);
            }
        }
        return u;
    }

    @IsTest
    static void usuarioSemPermissionSetNaoLeNemRegistra() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('S1-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-S1');
        Lote__c lote = TestDataFactory.criarLote(prod.Id, 'LS-1', Date.today().addDays(5));
        TestDataFactory.criarSaldo(lote.Id, pos.Id, 10);
        User u = criarUsuario(false);

        System.runAs(u) {
            try {
                WmsController.listarDepositos();
                Assert.fail('listarDepositos deveria ser bloqueado sem permissão');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException, 'esperava bloqueio de acesso, veio: ' + e.getMessage());
            }
            try {
                WmsController.lotesAVencer(30);
                Assert.fail('lotesAVencer deveria ser bloqueado sem permissão');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException, 'esperava bloqueio de acesso, veio: ' + e.getMessage());
            }
            try {
                FefoService.sugerirLote(prod.Id, pos.Id, 1);
                Assert.fail('sugerirLote deveria ser bloqueado sem permissão');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException, 'esperava bloqueio de acesso, veio: ' + e.getMessage());
            }
            try {
                WmsController.registrarMovimentacao(MovimentacaoTipo.ENTRADA, lote.Id, null, pos.Id, 1);
                Assert.fail('registrarMovimentacao deveria ser bloqueado sem permissão');
            } catch (AuraHandledException e) {
                Assert.isNotNull(e.getMessage());
            }
        }
        Assert.areEqual(0, [SELECT COUNT() FROM Movimentacao_Estoque__c]);
    }

    @IsTest
    static void operadorConsultaERegistraMasNaoEscreveSaldoDiretamente() {
        Posicao__c pos = TestDataFactory.criarPosicaoCompleta('S2-01');
        Produto__c prod = TestDataFactory.criarProduto('SKU-S2');
        Lote__c lote = TestDataFactory.criarLote(prod.Id, 'LS-2', Date.today().addDays(5));
        TestDataFactory.criarSaldo(lote.Id, pos.Id, 10);
        User u = criarUsuario(true);

        System.runAs(u) {
            Assert.areEqual(1, WmsController.listarDepositos().size());
            Assert.areEqual(1, WmsController.lotesAVencer(30).size());
            Assert.areEqual(lote.Id, FefoService.sugerirLote(prod.Id, pos.Id, 1).loteId);

            WmsController.registrarMovimentacao(MovimentacaoTipo.ENTRADA, lote.Id, null, pos.Id, 5);
            Assert.areEqual(15, TestDataFactory.saldo(lote.Id, pos.Id), 'o trigger atualiza o saldo em system mode');

            try {
                insert as user new Saldo_Estoque__c(
                    Chave__c = 'manual', Lote__c = lote.Id, Posicao__c = pos.Id, Quantidade_Atual__c = 999
                );
                Assert.fail('operador não pode escrever Saldo_Estoque__c diretamente');
            } catch (Exception e) {
                Assert.isFalse(e instanceof AssertException, 'esperava bloqueio, veio: ' + e.getMessage());
            }
        }
    }
}
