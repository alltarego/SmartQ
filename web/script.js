const API_URL = "https://smartq-production-319f.up.railway.app";

const filaSelect = document.getElementById("filaSelect");
const senhaAtual = document.getElementById("senhaAtual");
const quantidadeAguardando = document.getElementById("quantidadeAguardando");
const proximaSenha = document.getElementById("proximaSenha");
const btnChamar = document.getElementById("btnChamar");
const btnFinalizar = document.getElementById("btnFinalizar");

async function carregarFilas() {
    try {
        const resposta = await fetch(`${API_URL}/filas`);

        if (!resposta.ok) {
            throw new Error("Erro ao buscar filas");
        }

        const filas = await resposta.json();

        filaSelect.innerHTML = "";

        filas.forEach((fila) => {
            const option = document.createElement("option");

            option.value = fila.id;
            option.textContent = fila.nome;

            filaSelect.appendChild(option);
        });

        carregarStatusFila();

    } catch (erro) {
        console.error(erro);

        filaSelect.innerHTML =
            '<option value="">Erro ao carregar filas</option>';
    }
}

async function carregarStatusFila() {
    const filaId = filaSelect.value;

    if (!filaId) {
        return;
    }

    try {
        const resposta = await fetch(`${API_URL}/filas/${filaId}/status`);

        if (!resposta.ok) {
            throw new Error("Erro ao buscar status da fila");
        }

        const statusFila = await resposta.json();

        senhaAtual.textContent = statusFila.senhaAtual ?? "-";
        quantidadeAguardando.textContent = statusFila.quantidadeAguardando;
        proximaSenha.textContent = statusFila.proximaSenha ?? "-";

    } catch (erro) {
        console.error(erro);
    }
}

async function chamarProxima() {
    const filaId = filaSelect.value;

    if (!filaId) {
        return;
    }

    try {
        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/chamar-proxima`,
            {
                method: "POST"
            }
        );

        const dados = await resposta.json();

        if (!resposta.ok) {
            alert(dados.erro);
            return;
        }

        await carregarStatusFila();

    } catch (erro) {
        console.error(erro);
        alert("Erro ao chamar próxima senha");
    }
}

async function finalizarAtendimento() {
    const filaId = filaSelect.value;

    if (!filaId) {
        return;
    }

    try {
        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/finalizar-atendimento`,
            {
                method: "POST"
            }
        );

        const dados = await resposta.json();

        if (!resposta.ok) {
            alert(dados.erro);
            return;
        }

        await carregarStatusFila();

    } catch (erro) {
        console.error(erro);
        alert("Erro ao finalizar atendimento");
    }
}

filaSelect.addEventListener("change", carregarStatusFila);
btnChamar.addEventListener("click", chamarProxima);
btnFinalizar.addEventListener("click", finalizarAtendimento);

carregarFilas();

setInterval(() => {
    console.log("Atualizando status da fila...");
    carregarStatusFila();
}, 2000);

