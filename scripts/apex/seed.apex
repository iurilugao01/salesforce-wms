Deposito__c d = new Deposito__c(Name = 'Depósito SP', Endereco__c = 'Av. Paulista, 1000', Ativo__c = true);
insert d;
Zona__c z = new Zona__c(Name = 'Zona A', Deposito__c = d.Id, Tipo__c = 'Armazenagem');
insert z;
Corredor__c c = new Corredor__c(Name = 'Corredor 1', Zona__c = z.Id);
insert c;
List<Posicao__c> posicoes = new List<Posicao__c>();
for (Integer i = 1; i <= 4; i++) {
    posicoes.add(new Posicao__c(Name = 'A1-0' + i, Corredor__c = c.Id, Capacidade_Maxima__c = 200, Ativa__c = true));
}
insert posicoes;
Produto__c leite = new Produto__c(Name = 'Leite Integral 1L', SKU__c = 'LEITE-1L', Unidade_Medida__c = 'CX', Estoque_Minimo__c = 50);
Produto__c arroz = new Produto__c(Name = 'Arroz 5kg', SKU__c = 'ARROZ-5KG', Unidade_Medida__c = 'UN', Estoque_Minimo__c = 30);
insert new List<Produto__c>{ leite, arroz };
Lote__c l1 = new Lote__c(Name = 'LT-LEITE-001', Produto__c = leite.Id, Data_Fabricacao__c = Date.today().addDays(-20), Data_Validade__c = Date.today().addDays(12), Quantidade_Recebida__c = 120);
Lote__c l2 = new Lote__c(Name = 'LT-LEITE-002', Produto__c = leite.Id, Data_Fabricacao__c = Date.today().addDays(-5), Data_Validade__c = Date.today().addDays(90), Quantidade_Recebida__c = 80);
Lote__c l3 = new Lote__c(Name = 'LT-ARROZ-001', Produto__c = arroz.Id, Data_Fabricacao__c = Date.today().addDays(-60), Data_Validade__c = Date.today().addDays(300), Quantidade_Recebida__c = 150);
insert new List<Lote__c>{ l1, l2, l3 };
insert new List<Movimentacao_Estoque__c>{
    new Movimentacao_Estoque__c(Tipo__c = 'Entrada', Lote__c = l1.Id, Posicao_Destino__c = posicoes[0].Id, Quantidade__c = 120),
    new Movimentacao_Estoque__c(Tipo__c = 'Entrada', Lote__c = l2.Id, Posicao_Destino__c = posicoes[1].Id, Quantidade__c = 80),
    new Movimentacao_Estoque__c(Tipo__c = 'Entrada', Lote__c = l3.Id, Posicao_Destino__c = posicoes[2].Id, Quantidade__c = 150)
};
insert new List<Movimentacao_Estoque__c>{
    new Movimentacao_Estoque__c(Tipo__c = 'Saida', Lote__c = l1.Id, Posicao_Origem__c = posicoes[0].Id, Quantidade__c = 20),
    new Movimentacao_Estoque__c(Tipo__c = 'Transferencia', Lote__c = l3.Id, Posicao_Origem__c = posicoes[2].Id, Posicao_Destino__c = posicoes[3].Id, Quantidade__c = 40)
};
