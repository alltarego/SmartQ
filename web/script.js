const API_URL =
    "https://smartq-production-319f.up.railway.app";


// ======================================================
// ELEMENTOS - LOGIN
// ======================================================

const loginPage =
    document.getElementById("loginPage");

const adminPage =
    document.getElementById("adminPage");

const loginEmail =
    document.getElementById("loginEmail");

const loginSenha =
    document.getElementById("loginSenha");

const btnLogin =
    document.getElementById("btnLogin");

const loginMensagem =
    document.getElementById("loginMensagem");


// ======================================================
// ELEMENTOS - USUÁRIO
// ======================================================

const usuarioNome =
    document.getElementById("usuarioNome");

const usuarioEmail =
    document.getElementById("usuarioEmail");

const btnSair =
    document.getElementById("btnSair");


// ======================================================
// ELEMENTOS - FILA
// ======================================================

const filaSelect =
    document.getElementById("filaSelect");

const statusFilaBadge =
    document.getElementById("statusFilaBadge");

const btnAlternarStatus =
    document.getElementById("btnAlternarStatus");

const btnResetar =
    document.getElementById("btnResetar");

const mensagemFila =
    document.getElementById("mensagemFila");


// ======================================================
// ELEMENTOS - ATENDIMENTO
// ======================================================

const senhaAtual =
    document.getElementById("senhaAtual");

const quantidadeAguardando =
    document.getElementById("quantidadeAguardando");

const proximaSenha =
    document.getElementById("proximaSenha");

const proximoNumero =
    document.getElementById("proximoNumero");

const btnChamar =
    document.getElementById("btnChamar");

const btnFinalizar =
    document.getElementById("btnFinalizar");

const mensagemAtendimento =
    document.getElementById("mensagemAtendimento");


// ======================================================
// ELEMENTOS - CRIAÇÃO DE FILA
// ======================================================

const novaFilaNome =
    document.getElementById("novaFilaNome");

const btnCriarFila =
    document.getElementById("btnCriarFila");

const mensagemNovaFila =
    document.getElementById("mensagemNovaFila");


// ======================================================
// ESTADO
// ======================================================

let token =
    localStorage.getItem("smartq_token");

let usuario = JSON.parse(
    localStorage.getItem("smartq_usuario") || "null"
);

let statusFilaAtual = null;


// ======================================================
// FUNÇÕES AUXILIARES
// ======================================================

function headersAutenticados() {
    return {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`
    };
}


function mostrarMensagem(
    elemento,
    texto,
    tipo = ""
) {
    elemento.textContent = texto;

    elemento.classList.remove(
        "erro",
        "sucesso"
    );

    if (tipo) {
        elemento.classList.add(tipo);
    }
}


function limparMensagem(elemento) {
    mostrarMensagem(elemento, "");
}


function tratarSessaoExpirada(resposta) {

    if (
        resposta.status === 401 ||
        resposta.status === 403
    ) {
        logout();

        return true;
    }

    return false;
}


// ======================================================
// LOGIN
// ======================================================

async function login() {

    const email =
        loginEmail.value.trim();

    const senha =
        loginSenha.value;

    limparMensagem(loginMensagem);

    if (!email || !senha) {
        mostrarMensagem(
            loginMensagem,
            "Informe o e-mail e a senha.",
            "erro"
        );

        return;
    }

    btnLogin.disabled = true;
    btnLogin.textContent = "Entrando...";

    try {

        const resposta = await fetch(
            `${API_URL}/auth/login`,
            {
                method: "POST",

                headers: {
                    "Content-Type":
                        "application/json"
                },

                body: JSON.stringify({
                    email,
                    senha
                })
            }
        );

        const dados = await resposta.json();

        if (!resposta.ok) {
            mostrarMensagem(
                loginMensagem,
                dados.erro || "Erro ao realizar login.",
                "erro"
            );

            return;
        }

        if (dados.usuario.tipo !== "admin") {
            mostrarMensagem(
                loginMensagem,
                "Esta conta não possui acesso administrativo.",
                "erro"
            );

            return;
        }

        token = dados.token;
        usuario = dados.usuario;

        localStorage.setItem(
            "smartq_token",
            token
        );

        localStorage.setItem(
            "smartq_usuario",
            JSON.stringify(usuario)
        );

        abrirPainel();

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            loginMensagem,
            "Não foi possível conectar ao servidor.",
            "erro"
        );

    } finally {

        btnLogin.disabled = false;
        btnLogin.textContent = "Entrar";
    }
}


// ======================================================
// LOGOUT
// ======================================================

function logout() {

    token = null;
    usuario = null;

    localStorage.removeItem(
        "smartq_token"
    );

    localStorage.removeItem(
        "smartq_usuario"
    );

    adminPage.classList.add("oculto");
    loginPage.classList.remove("oculto");

    loginSenha.value = "";
}


// ======================================================
// ABRIR PAINEL
// ======================================================

async function abrirPainel() {

    if (
        !token ||
        !usuario ||
        usuario.tipo !== "admin"
    ) {
        logout();
        return;
    }

    loginPage.classList.add("oculto");
    adminPage.classList.remove("oculto");

    usuarioNome.textContent =
        usuario.nome;

    usuarioEmail.textContent =
        usuario.email;

    await carregarFilas();
}


// ======================================================
// CARREGAR FILAS
// ======================================================

async function carregarFilas(
    selecionarFilaId = null
) {

    try {

        const resposta = await fetch(
            `${API_URL}/filas`
        );

        if (!resposta.ok) {
            throw new Error(
                "Erro ao buscar filas"
            );
        }

        const filas =
            await resposta.json();

        const filaAnterior =
            selecionarFilaId ||
            filaSelect.value;

        filaSelect.innerHTML = "";

        if (filas.length === 0) {

            filaSelect.innerHTML =
                '<option value="">Nenhuma fila cadastrada</option>';

            limparDadosFila();

            return;
        }

        filas.forEach((fila) => {

            const option =
                document.createElement("option");

            option.value = fila.id;
            option.textContent = fila.nome;

            filaSelect.appendChild(option);
        });

        const filaExiste =
            filas.some(
                (fila) =>
                    String(fila.id) ===
                    String(filaAnterior)
            );

        if (filaAnterior && filaExiste) {
            filaSelect.value =
                String(filaAnterior);
        }

        await selecionarFila();

    } catch (erro) {

        console.error(erro);

        filaSelect.innerHTML =
            '<option value="">Erro ao carregar filas</option>';
    }
}


// ======================================================
// SELECIONAR FILA
// ======================================================

async function selecionarFila() {

    const filaId =
        parseInt(filaSelect.value);

    if (!filaId) {
        limparDadosFila();
        return;
    }

    limparMensagem(mensagemFila);

    await Promise.all([
        carregarStatusFila(),
        sincronizarPainelIoT(filaId)
    ]);
}


// ======================================================
// SINCRONIZAR PAINEL IOT
// ======================================================

async function sincronizarPainelIoT(
    filaId
) {

    try {

        const resposta = await fetch(
            `${API_URL}/paineis/1/fila`,
            {
                method: "PUT",

                headers:
                    headersAutenticados(),

                body: JSON.stringify({
                    filaId
                })
            }
        );

        if (tratarSessaoExpirada(resposta)) {
            return;
        }

        const dados =
            await resposta.json();

        if (!resposta.ok) {

            mostrarMensagem(
                mensagemFila,
                dados.erro ||
                    "Não foi possível atualizar o painel IoT.",
                "erro"
            );

            return;
        }

        mostrarMensagem(
            mensagemFila,
            "Fila sincronizada com o painel IoT.",
            "sucesso"
        );

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            mensagemFila,
            "Erro ao sincronizar o painel IoT.",
            "erro"
        );
    }
}


// ======================================================
// STATUS DA FILA
// ======================================================

async function carregarStatusFila() {

    const filaId =
        filaSelect.value;

    if (!filaId) {
        return;
    }

    try {

        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/status`
        );

        if (!resposta.ok) {
            throw new Error(
                "Erro ao buscar status da fila"
            );
        }

        const dados =
            await resposta.json();

        statusFilaAtual =
            dados.status;

        senhaAtual.textContent =
            dados.senhaAtual ?? "-";

        quantidadeAguardando.textContent =
            dados.quantidadeAguardando;

        proximaSenha.textContent =
            dados.proximaSenha ?? "-";

        proximoNumero.textContent =
            dados.proximoNumero;

        atualizarStatusVisual();

    } catch (erro) {

        console.error(erro);
    }
}


// ======================================================
// VISUAL DO STATUS
// ======================================================

function atualizarStatusVisual() {

    statusFilaBadge.classList.remove(
        "aberta",
        "fechada"
    );

    if (statusFilaAtual === "aberta") {

        statusFilaBadge.textContent =
            "ABERTA";

        statusFilaBadge.classList.add(
            "aberta"
        );

        btnAlternarStatus.textContent =
            "Fechar fila";

        btnChamar.disabled = false;

    } else if (
        statusFilaAtual === "fechada"
    ) {

        statusFilaBadge.textContent =
            "FECHADA";

        statusFilaBadge.classList.add(
            "fechada"
        );

        btnAlternarStatus.textContent =
            "Abrir fila";

        btnChamar.disabled = true;

    } else {

        statusFilaBadge.textContent = "-";

        btnAlternarStatus.textContent =
            "Abrir / Fechar fila";
    }
}


// ======================================================
// ABRIR / FECHAR FILA
// ======================================================

async function alternarStatusFila() {

    const filaId =
        filaSelect.value;

    if (!filaId || !statusFilaAtual) {
        return;
    }

    const novoStatus =
        statusFilaAtual === "aberta"
            ? "fechada"
            : "aberta";

    try {

        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/status`,
            {
                method: "PUT",

                headers:
                    headersAutenticados(),

                body: JSON.stringify({
                    status: novoStatus
                })
            }
        );

        if (tratarSessaoExpirada(resposta)) {
            return;
        }

        const dados =
            await resposta.json();

        if (!resposta.ok) {

            mostrarMensagem(
                mensagemFila,
                dados.erro,
                "erro"
            );

            return;
        }

        mostrarMensagem(
            mensagemFila,
            dados.mensagem,
            "sucesso"
        );

        await carregarStatusFila();

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            mensagemFila,
            "Erro ao alterar a fila.",
            "erro"
        );
    }
}


// ======================================================
// RESETAR FILA
// ======================================================

async function resetarFila() {

    const filaId =
        filaSelect.value;

    if (!filaId) {
        return;
    }

    const confirmar = confirm(
        "Deseja realmente reiniciar esta fila?\n\n" +
        "As senhas que ainda estiverem aguardando serão canceladas " +
        "e a numeração voltará para A001."
    );

    if (!confirmar) {
        return;
    }

    try {

        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/resetar`,
            {
                method: "PUT",
                headers:
                    headersAutenticados()
            }
        );

        if (tratarSessaoExpirada(resposta)) {
            return;
        }

        const dados =
            await resposta.json();

        if (!resposta.ok) {

            mostrarMensagem(
                mensagemFila,
                dados.erro,
                "erro"
            );

            return;
        }

        mostrarMensagem(
            mensagemFila,
            `Fila reiniciada. ${dados.senhasCanceladas} senha(s) aguardando foram canceladas.`,
            "sucesso"
        );

        await carregarStatusFila();

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            mensagemFila,
            "Erro ao reiniciar a fila.",
            "erro"
        );
    }
}


// ======================================================
// CHAMAR PRÓXIMA
// ======================================================

async function chamarProxima() {

    const filaId =
        filaSelect.value;

    if (!filaId) {
        return;
    }

    limparMensagem(
        mensagemAtendimento
    );

    try {

        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/chamar-proxima`,
            {
                method: "POST",

                headers:
                    headersAutenticados()
            }
        );

        if (tratarSessaoExpirada(resposta)) {
            return;
        }

        const dados =
            await resposta.json();

        if (!resposta.ok) {

            mostrarMensagem(
                mensagemAtendimento,
                dados.erro,
                "erro"
            );

            return;
        }

        mostrarMensagem(
            mensagemAtendimento,
            `${dados.senha.codigo} chamada para atendimento.`,
            "sucesso"
        );

        await carregarStatusFila();

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            mensagemAtendimento,
            "Erro ao chamar próxima senha.",
            "erro"
        );
    }
}


// ======================================================
// FINALIZAR ATENDIMENTO
// ======================================================

async function finalizarAtendimento() {

    const filaId =
        filaSelect.value;

    if (!filaId) {
        return;
    }

    limparMensagem(
        mensagemAtendimento
    );

    try {

        const resposta = await fetch(
            `${API_URL}/filas/${filaId}/finalizar-atendimento`,
            {
                method: "POST",

                headers:
                    headersAutenticados()
            }
        );

        if (tratarSessaoExpirada(resposta)) {
            return;
        }

        const dados =
            await resposta.json();

        if (!resposta.ok) {

            mostrarMensagem(
                mensagemAtendimento,
                dados.erro,
                "erro"
            );

            return;
        }

        mostrarMensagem(
            mensagemAtendimento,
            `${dados.senha.codigo} finalizada com sucesso.`,
            "sucesso"
        );

        await carregarStatusFila();

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            mensagemAtendimento,
            "Erro ao finalizar atendimento.",
            "erro"
        );
    }
}


// ======================================================
// CRIAR NOVA FILA
// ======================================================

async function criarFila() {

    const nome =
        novaFilaNome.value.trim();

    limparMensagem(
        mensagemNovaFila
    );

    if (!nome) {

        mostrarMensagem(
            mensagemNovaFila,
            "Digite o nome da fila.",
            "erro"
        );

        return;
    }

    btnCriarFila.disabled = true;

    try {

        const resposta = await fetch(
            `${API_URL}/filas`,
            {
                method: "POST",

                headers:
                    headersAutenticados(),

                body: JSON.stringify({
                    nome
                })
            }
        );

        if (tratarSessaoExpirada(resposta)) {
            return;
        }

        const dados =
            await resposta.json();

        if (!resposta.ok) {

            mostrarMensagem(
                mensagemNovaFila,
                dados.erro,
                "erro"
            );

            return;
        }

        novaFilaNome.value = "";

        mostrarMensagem(
            mensagemNovaFila,
            `Fila "${dados.nome}" criada com sucesso.`,
            "sucesso"
        );

        await carregarFilas(
            dados.id
        );

    } catch (erro) {

        console.error(erro);

        mostrarMensagem(
            mensagemNovaFila,
            "Erro ao criar fila.",
            "erro"
        );

    } finally {

        btnCriarFila.disabled = false;
    }
}


// ======================================================
// LIMPAR DADOS
// ======================================================

function limparDadosFila() {

    statusFilaAtual = null;

    senhaAtual.textContent = "-";
    quantidadeAguardando.textContent = "0";
    proximaSenha.textContent = "-";
    proximoNumero.textContent = "-";

    statusFilaBadge.textContent = "-";

    statusFilaBadge.classList.remove(
        "aberta",
        "fechada"
    );
}


// ======================================================
// EVENTOS
// ======================================================

btnLogin.addEventListener(
    "click",
    login
);

loginSenha.addEventListener(
    "keydown",
    (evento) => {

        if (evento.key === "Enter") {
            login();
        }
    }
);

btnSair.addEventListener(
    "click",
    logout
);

filaSelect.addEventListener(
    "change",
    selecionarFila
);

btnAlternarStatus.addEventListener(
    "click",
    alternarStatusFila
);

btnResetar.addEventListener(
    "click",
    resetarFila
);

btnChamar.addEventListener(
    "click",
    chamarProxima
);

btnFinalizar.addEventListener(
    "click",
    finalizarAtendimento
);

btnCriarFila.addEventListener(
    "click",
    criarFila
);

novaFilaNome.addEventListener(
    "keydown",
    (evento) => {

        if (evento.key === "Enter") {
            criarFila();
        }
    }
);


// ======================================================
// ATUALIZAÇÃO AUTOMÁTICA
// ======================================================

setInterval(() => {

    if (
        token &&
        !adminPage.classList.contains("oculto")
    ) {
        carregarStatusFila();
    }

}, 2000);


// ======================================================
// INICIALIZAÇÃO
// ======================================================

if (
    token &&
    usuario &&
    usuario.tipo === "admin"
) {
    abrirPainel();

} else {
    logout();
}