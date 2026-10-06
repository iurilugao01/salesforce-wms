import { createElement } from 'lwc';
import VisaoDeposito from 'c/visaoDeposito';
import listarDepositos from '@salesforce/apex/WmsController.listarDepositos';
import buscarHierarquia from '@salesforce/apex/WmsController.buscarHierarquia';

jest.mock('@salesforce/apex/WmsController.listarDepositos', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/WmsController.buscarHierarquia', () => ({ default: jest.fn() }), { virtual: true });

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

function criar() {
    const el = createElement('c-visao-deposito', { is: VisaoDeposito });
    document.body.appendChild(el);
    return el;
}
const selecionar = (el, value) =>
    el.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change', { detail: { value } }));

describe('c-visao-deposito', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('carrega os depósitos no combobox', async () => {
        listarDepositos.mockResolvedValue([{ id: 'd1', nome: 'Depósito SP' }]);
        const el = criar();
        await flush();
        expect(el.shadowRoot.querySelector('lightning-combobox').options).toEqual([{ label: 'Depósito SP', value: 'd1' }]);
    });

    it('ao selecionar mostra zonas, corredores e posições com a ocupação', async () => {
        listarDepositos.mockResolvedValue([{ id: 'd1', nome: 'Depósito SP' }]);
        buscarHierarquia.mockResolvedValue({
            zonas: [
                {
                    id: 'z1', nome: 'Zona A', tipo: 'Armazenagem',
                    corredores: [
                        {
                            id: 'c1', nome: 'Corredor 1',
                            posicoes: [
                                { id: 'p1', codigo: 'A1-01', capacidade: 100, ocupado: 40, percentual: 40, ativa: true },
                                { id: 'p2', codigo: 'A1-02', capacidade: null, ocupado: 5, percentual: 0, ativa: true }
                            ]
                        }
                    ]
                }
            ]
        });
        const el = criar();
        await flush();
        selecionar(el, 'd1');
        await flush();
        expect(buscarHierarquia).toHaveBeenCalledWith({ depositoId: 'd1' });
        const codigos = [...el.shadowRoot.querySelectorAll('.posicao-codigo')].map((n) => n.textContent);
        expect(codigos).toEqual(['A1-01', 'A1-02']);
        const barras = el.shadowRoot.querySelectorAll('lightning-progress-bar');
        expect(barras).toHaveLength(2);
        expect(barras[0].value).toBe(40);
        expect(barras[1].value).toBe(0);
    });

    it('depósito sem zonas mostra estado vazio', async () => {
        listarDepositos.mockResolvedValue([{ id: 'd2', nome: 'Vazio' }]);
        buscarHierarquia.mockResolvedValue({ zonas: [] });
        const el = criar();
        await flush();
        selecionar(el, 'd2');
        await flush();
        expect(el.shadowRoot.querySelector('.mensagem-vazio')).not.toBeNull();
    });

    it('mostra erro quando a busca falha', async () => {
        listarDepositos.mockRejectedValue({ body: { message: 'Falha ao listar' } });
        const el = criar();
        await flush();
        expect(el.shadowRoot.querySelector('.mensagem-erro').textContent).toContain('Falha ao listar');
    });
});
