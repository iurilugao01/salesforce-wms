import { createElement } from 'lwc';
import RegistrarMovimentacao from 'c/registrarMovimentacao';
import registrar from '@salesforce/apex/WmsController.registrarMovimentacao';
import lotesDisponiveis from '@salesforce/apex/WmsController.lotesDisponiveis';
import sugerirLote from '@salesforce/apex/FefoService.sugerirLote';
const TOAST_EVENT = 'lightning__showtoast';

jest.mock('@salesforce/apex/WmsController.registrarMovimentacao', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/WmsController.lotesDisponiveis', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/FefoService.sugerirLote', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function criar() {
    const el = createElement('c-registrar-movimentacao', { is: RegistrarMovimentacao });
    document.body.appendChild(el);
    return el;
}
const q = (el, seletor) => el.shadowRoot.querySelector(seletor);
const picker = (el, id) => q(el, `lightning-record-picker[data-id="${id}"]`);
const escolher = (el, id, recordId) =>
    picker(el, id).dispatchEvent(new CustomEvent('change', { detail: { recordId } }));
const escolherTipo = (el, value) =>
    q(el, 'lightning-radio-group').dispatchEvent(new CustomEvent('change', { detail: { value } }));
const digitarQuantidade = (el, value) =>
    q(el, 'lightning-input[data-id="quantidade"]').dispatchEvent(new CustomEvent('change', { detail: { value } }));

describe('c-registrar-movimentacao', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('Entrada mostra destino e esconde origem; botão começa desabilitado', async () => {
        const el = criar();
        await flush();
        expect(picker(el, 'destino')).not.toBeNull();
        expect(picker(el, 'origem')).toBeNull();
        expect(q(el, 'lightning-button[data-id="salvar"]').disabled).toBe(true);
        expect(lotesDisponiveis).not.toHaveBeenCalled();
    });

    it('Saída mostra origem e esconde destino', async () => {
        const el = criar();
        escolherTipo(el, 'Saida');
        await flush();
        expect(picker(el, 'origem')).not.toBeNull();
        expect(picker(el, 'destino')).toBeNull();
    });

    it('Saída sugere o lote FEFO ao escolher produto e origem', async () => {
        lotesDisponiveis.mockResolvedValue([{ loteId: 'a0L1', rotulo: 'L-1 (val. 2026-12-01) — saldo 40', saldo: 40 }]);
        sugerirLote.mockResolvedValue({ loteId: 'a0L1', numeroLote: 'L-1', validade: '2026-12-01', saldo: 40 });
        const el = criar();
        escolherTipo(el, 'Saida');
        await flush();
        escolher(el, 'produto', 'a0P1');
        escolher(el, 'origem', 'a0S1');
        await flush();
        expect(sugerirLote).toHaveBeenCalledWith({ produtoId: 'a0P1', posicaoId: 'a0S1', quantidade: 0 });
        expect(q(el, '.sugestao-fefo').textContent).toContain('L-1');
        expect(q(el, 'lightning-combobox[data-id="lote-combobox"]').value).toBe('a0L1');
    });

    it('Entrada salva chamando o Apex com os parâmetros certos e mostra toast', async () => {
        registrar.mockResolvedValue('a0M1');
        const el = criar();
        const toasts = [];
        el.addEventListener(TOAST_EVENT, (e) => toasts.push(e.detail));
        await flush();
        escolher(el, 'produto', 'a0P1');
        await flush();
        escolher(el, 'destino', 'a0S2');
        escolher(el, 'lote-picker', 'a0L1');
        digitarQuantidade(el, '25');
        await flush();
        const botao = q(el, 'lightning-button[data-id="salvar"]');
        expect(botao.disabled).toBe(false);
        botao.click();
        await flush();
        expect(registrar).toHaveBeenCalledWith({
            tipo: 'Entrada', loteId: 'a0L1', origemId: null, destinoId: 'a0S2', quantidade: 25
        });
        expect(toasts).toHaveLength(1);
        expect(toasts[0].variant).toBe('success');
    });

    it('Exibe a mensagem de erro devolvida pelo Apex e não mostra toast de sucesso', async () => {
        registrar.mockRejectedValue({ body: { message: 'Saldo insuficiente na posição de origem. Disponível: 5.' } });
        const el = criar();
        const toasts = [];
        el.addEventListener(TOAST_EVENT, (e) => toasts.push(e.detail));
        await flush();
        escolher(el, 'produto', 'a0P1');
        await flush();
        escolher(el, 'destino', 'a0S2');
        escolher(el, 'lote-picker', 'a0L1');
        digitarQuantidade(el, '25');
        await flush();
        q(el, 'lightning-button[data-id="salvar"]').click();
        await flush();
        expect(q(el, '.mensagem-erro').textContent).toContain('Saldo insuficiente');
        expect(toasts).toHaveLength(0);
    });
});
