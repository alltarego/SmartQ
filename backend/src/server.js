const express = require("express");
const cors = require("cors");
const db = require("./database");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");

const app = express();

app.use(cors());
app.use(express.json());


// ======================================================
// MIDDLEWARES DE AUTENTICAÇÃO
// ======================================================

function autenticar(req, res, next) {
    const authorization = req.headers.authorization;

    if (!authorization) {
        return res.status(401).json({
            erro: "Token não informado"
        });
    }

    const partes = authorization.split(" ");

    if (
        partes.length !== 2 ||
        partes[0] !== "Bearer"
    ) {
        return res.status(401).json({
            erro: "Token inválido"
        });
    }

    const token = partes[1];

    try {
        const dados = jwt.verify(
            token,
            process.env.JWT_SECRET
        );

        req.usuario = dados;

        next();

    } catch (erro) {
        return res.status(401).json({
            erro: "Token inválido ou expirado"
        });
    }
}


function somenteAdmin(req, res, next) {
    if (
        !req.usuario ||
        req.usuario.tipo !== "admin"
    ) {
        return res.status(403).json({
            erro: "Acesso permitido somente para administradores"
        });
    }

    next();
}


// ======================================================
// ROTA PRINCIPAL
// ======================================================

app.get("/", (req, res) => {
    res.json({
        message: "SmartQ API funcionando"
    });
});


// ======================================================
// AUTENTICAÇÃO
// ======================================================

// Cadastro de cliente
app.post("/auth/cadastro", async (req, res) => {
    const { nome, email, senha } = req.body;

    if (!nome || !email || !senha) {
        return res.status(400).json({
            erro: "Nome, e-mail e senha são obrigatórios"
        });
    }

    if (senha.length < 6) {
        return res.status(400).json({
            erro: "A senha deve possuir pelo menos 6 caracteres"
        });
    }

    const emailNormalizado = email.trim().toLowerCase();

    try {
        const [usuariosExistentes] = await db.query(
            "SELECT id FROM usuarios WHERE email = ?",
            [emailNormalizado]
        );

        if (usuariosExistentes.length > 0) {
            return res.status(409).json({
                erro: "Já existe um usuário cadastrado com este e-mail"
            });
        }

        const senhaHash = await bcrypt.hash(senha, 10);

        const [resultado] = await db.query(
            `INSERT INTO usuarios
             (nome, email, senha_hash, tipo)
             VALUES (?, ?, ?, 'cliente')`,
            [
                nome.trim(),
                emailNormalizado,
                senhaHash
            ]
        );

        res.status(201).json({
            mensagem: "Usuário cadastrado com sucesso",
            usuario: {
                id: resultado.insertId,
                nome: nome.trim(),
                email: emailNormalizado,
                tipo: "cliente"
            }
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao cadastrar usuário"
        });
    }
});


// Login
app.post("/auth/login", async (req, res) => {
    const { email, senha } = req.body;

    if (!email || !senha) {
        return res.status(400).json({
            erro: "E-mail e senha são obrigatórios"
        });
    }

    try {
        const [usuarios] = await db.query(
            `SELECT
                id,
                nome,
                email,
                senha_hash,
                tipo
             FROM usuarios
             WHERE email = ?`,
            [email.trim().toLowerCase()]
        );

        if (usuarios.length === 0) {
            return res.status(401).json({
                erro: "E-mail ou senha inválidos"
            });
        }

        const usuario = usuarios[0];

        const senhaCorreta = await bcrypt.compare(
            senha,
            usuario.senha_hash
        );

        if (!senhaCorreta) {
            return res.status(401).json({
                erro: "E-mail ou senha inválidos"
            });
        }

        const token = jwt.sign(
            {
                id: usuario.id,
                tipo: usuario.tipo
            },
            process.env.JWT_SECRET,
            {
                expiresIn: "8h"
            }
        );

        res.json({
            mensagem: "Login realizado com sucesso",
            token,
            usuario: {
                id: usuario.id,
                nome: usuario.nome,
                email: usuario.email,
                tipo: usuario.tipo
            }
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao realizar login"
        });
    }
});


// Consultar usuário autenticado
app.get(
    "/auth/me",
    autenticar,
    async (req, res) => {
        try {
            const [usuarios] = await db.query(
                `SELECT
                    id,
                    nome,
                    email,
                    tipo
                 FROM usuarios
                 WHERE id = ?`,
                [req.usuario.id]
            );

            if (usuarios.length === 0) {
                return res.status(404).json({
                    erro: "Usuário não encontrado"
                });
            }

            res.json({
                usuario: usuarios[0]
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao buscar usuário"
            });
        }
    }
);


// ======================================================
// FILAS
// ======================================================

// Listar filas
app.get("/filas", async (req, res) => {
    try {
        const [filasBanco] = await db.query(
            `SELECT
                id,
                nome,
                status,
                proximo_numero AS proximoNumero
             FROM filas
             ORDER BY id`
        );

        res.json(filasBanco);

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar filas"
        });
    }
});


// Criar fila - somente administrador
app.post(
    "/filas",
    autenticar,
    somenteAdmin,
    async (req, res) => {

        const { nome } = req.body;

        if (!nome || !nome.trim()) {
            return res.status(400).json({
                erro: "O nome da fila é obrigatório"
            });
        }

        try {
            const [resultado] = await db.query(
                `INSERT INTO filas
                 (nome, status, proximo_numero)
                 VALUES (?, 'aberta', 1)`,
                [nome.trim()]
            );

            res.status(201).json({
                id: resultado.insertId,
                nome: nome.trim(),
                status: "aberta",
                proximoNumero: 1
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao criar fila"
            });
        }
    }
);


// Abrir ou fechar fila - somente administrador
app.put(
    "/filas/:id/status",
    autenticar,
    somenteAdmin,
    async (req, res) => {

        const filaId = parseInt(req.params.id);
        const { status } = req.body;

        if (!["aberta", "fechada"].includes(status)) {
            return res.status(400).json({
                erro: "Status deve ser 'aberta' ou 'fechada'"
            });
        }

        try {
            const [resultado] = await db.query(
                `UPDATE filas
                 SET status = ?
                 WHERE id = ?`,
                [status, filaId]
            );

            if (resultado.affectedRows === 0) {
                return res.status(404).json({
                    erro: "Fila não encontrada"
                });
            }

            res.json({
                mensagem: `Fila ${status} com sucesso`,
                filaId,
                status
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao alterar status da fila"
            });
        }
    }
);


// Resetar fila - somente administrador
app.put(
    "/filas/:id/resetar",
    autenticar,
    somenteAdmin,
    async (req, res) => {

        const filaId = parseInt(req.params.id);

        let conexao;

        try {
            conexao = await db.getConnection();

            await conexao.beginTransaction();

            const [filasEncontradas] = await conexao.query(
                `SELECT id
                 FROM filas
                 WHERE id = ?
                 FOR UPDATE`,
                [filaId]
            );

            if (filasEncontradas.length === 0) {
                await conexao.rollback();

                return res.status(404).json({
                    erro: "Fila não encontrada"
                });
            }

            const [resultadoCancelamento] =
                await conexao.query(
                    `UPDATE senhas
                     SET status = 'cancelado'
                     WHERE fila_id = ?
                       AND status = 'aguardando'`,
                    [filaId]
                );

            await conexao.query(
                `UPDATE filas
                 SET proximo_numero = 1
                 WHERE id = ?`,
                [filaId]
            );

            await conexao.commit();

            res.json({
                mensagem: "Fila reiniciada com sucesso",
                filaId,
                proximoNumero: 1,
                senhasCanceladas:
                    resultadoCancelamento.affectedRows
            });

        } catch (erro) {

            if (conexao) {
                await conexao.rollback();
            }

            console.error(erro);

            res.status(500).json({
                erro: "Erro ao reiniciar fila"
            });

        } finally {

            if (conexao) {
                conexao.release();
            }
        }
    }
);


// ======================================================
// SENHAS DO USUÁRIO
// ======================================================

// Buscar senha ativa do usuário autenticado
app.get(
    "/minha-senha",
    autenticar,
    async (req, res) => {
        try {
            const [senhas] = await db.query(
                `SELECT
                    senhas.id,
                    senhas.fila_id AS filaId,
                    filas.nome AS filaNome,
                    senhas.codigo,
                    senhas.status,
                    senhas.criado_em AS criadoEm
                 FROM senhas
                 INNER JOIN filas
                    ON filas.id = senhas.fila_id
                 WHERE senhas.usuario_id = ?
                   AND senhas.status IN ('aguardando', 'chamando')
                 ORDER BY senhas.id DESC
                 LIMIT 1`,
                [req.usuario.id]
            );

            if (senhas.length === 0) {
                return res.json({
                    senha: null
                });
            }

            res.json({
                senha: senhas[0]
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao buscar senha ativa"
            });
        }
    }
);


// Criar senha para o usuário autenticado
app.post(
    "/filas/:id/senhas",
    autenticar,
    async (req, res) => {

        const filaId = parseInt(req.params.id);
        const usuarioId = req.usuario.id;

        let conexao;

        try {
            conexao = await db.getConnection();

            await conexao.beginTransaction();

            // Bloqueia o registro do usuário durante a criação.
            // Isso reduz o risco de duas requisições simultâneas
            // criarem duas senhas para a mesma conta.
            const [usuarios] = await conexao.query(
                `SELECT id
                 FROM usuarios
                 WHERE id = ?
                 FOR UPDATE`,
                [usuarioId]
            );

            if (usuarios.length === 0) {
                await conexao.rollback();

                return res.status(404).json({
                    erro: "Usuário não encontrado"
                });
            }

            const [senhasAtivas] = await conexao.query(
                `SELECT
                    senhas.id,
                    senhas.fila_id AS filaId,
                    filas.nome AS filaNome,
                    senhas.codigo,
                    senhas.status,
                    senhas.criado_em AS criadoEm
                 FROM senhas
                 INNER JOIN filas
                    ON filas.id = senhas.fila_id
                 WHERE senhas.usuario_id = ?
                   AND senhas.status IN ('aguardando', 'chamando')
                 ORDER BY senhas.id DESC
                 LIMIT 1`,
                [usuarioId]
            );

            if (senhasAtivas.length > 0) {
                await conexao.rollback();

                return res.status(409).json({
                    erro: "Você já possui uma senha ativa",
                    senha: senhasAtivas[0]
                });
            }

            const [filasEncontradas] =
                await conexao.query(
                    `SELECT
                        id,
                        nome,
                        status,
                        proximo_numero
                     FROM filas
                     WHERE id = ?
                     FOR UPDATE`,
                    [filaId]
                );

            if (filasEncontradas.length === 0) {
                await conexao.rollback();

                return res.status(404).json({
                    erro: "Fila não encontrada"
                });
            }

            const fila = filasEncontradas[0];

            if (fila.status !== "aberta") {
                await conexao.rollback();

                return res.status(400).json({
                    erro: "Esta fila está fechada"
                });
            }

            const numero = fila.proximo_numero;

            const codigo =
                `A${String(numero).padStart(3, "0")}`;

            const [resultado] = await conexao.query(
                `INSERT INTO senhas
                 (fila_id, usuario_id, codigo, status)
                 VALUES (?, ?, ?, 'aguardando')`,
                [
                    filaId,
                    usuarioId,
                    codigo
                ]
            );

            await conexao.query(
                `UPDATE filas
                 SET proximo_numero =
                    proximo_numero + 1
                 WHERE id = ?`,
                [filaId]
            );

            await conexao.commit();

            res.status(201).json({
                id: resultado.insertId,
                filaId,
                filaNome: fila.nome,
                usuarioId,
                codigo,
                status: "aguardando"
            });

        } catch (erro) {

            if (conexao) {
                await conexao.rollback();
            }

            console.error(erro);

            res.status(500).json({
                erro: "Erro ao criar senha"
            });

        } finally {

            if (conexao) {
                conexao.release();
            }
        }
    }
);


// Listar senhas de uma fila
app.get("/filas/:id/senhas", async (req, res) => {
    const filaId = parseInt(req.params.id);

    try {
        const [filasEncontradas] = await db.query(
            "SELECT id FROM filas WHERE id = ?",
            [filaId]
        );

        if (filasEncontradas.length === 0) {
            return res.status(404).json({
                erro: "Fila não encontrada"
            });
        }

        const [senhasDaFila] = await db.query(
            `SELECT
                id,
                fila_id AS filaId,
                usuario_id AS usuarioId,
                codigo,
                status,
                criado_em AS criadoEm
             FROM senhas
             WHERE fila_id = ?
             ORDER BY id`,
            [filaId]
        );

        res.json(senhasDaFila);

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar senhas"
        });
    }
});


// Buscar uma senha específica
app.get("/senhas/:id", async (req, res) => {
    const senhaId = parseInt(req.params.id);

    try {
        const [senhasEncontradas] = await db.query(
            `SELECT
                id,
                fila_id AS filaId,
                usuario_id AS usuarioId,
                codigo,
                status,
                criado_em AS criadoEm
             FROM senhas
             WHERE id = ?`,
            [senhaId]
        );

        if (senhasEncontradas.length === 0) {
            return res.status(404).json({
                erro: "Senha não encontrada"
            });
        }

        res.json(senhasEncontradas[0]);

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar senha"
        });
    }
});


// Cancelar senha do usuário autenticado
app.post(
    "/senhas/:id/cancelar",
    autenticar,
    async (req, res) => {

        const senhaId = parseInt(req.params.id);

        try {
            const [senhasEncontradas] = await db.query(
                `SELECT
                    id,
                    fila_id AS filaId,
                    usuario_id AS usuarioId,
                    codigo,
                    status
                 FROM senhas
                 WHERE id = ?`,
                [senhaId]
            );

            if (senhasEncontradas.length === 0) {
                return res.status(404).json({
                    erro: "Senha não encontrada"
                });
            }

            const senha = senhasEncontradas[0];

            // Administrador pode cancelar qualquer senha.
            // Cliente só pode cancelar a própria.
            if (
                req.usuario.tipo !== "admin" &&
                senha.usuarioId !== req.usuario.id
            ) {
                return res.status(403).json({
                    erro: "Você não pode cancelar esta senha"
                });
            }

            if (senha.status === "atendido") {
                return res.status(400).json({
                    erro: "Não é possível cancelar uma senha já atendida"
                });
            }

            if (senha.status === "cancelado") {
                return res.status(400).json({
                    erro: "A senha já está cancelada"
                });
            }

            if (senha.status === "chamando") {
                return res.status(400).json({
                    erro: "Não é possível cancelar uma senha que já foi chamada"
                });
            }

            await db.query(
                `UPDATE senhas
                 SET status = 'cancelado'
                 WHERE id = ?`,
                [senhaId]
            );

            senha.status = "cancelado";

            res.json({
                mensagem: "Senha cancelada com sucesso",
                senha
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao cancelar senha"
            });
        }
    }
);


// ======================================================
// ATENDIMENTO
// ======================================================

// Chamar próxima senha - somente administrador
app.post(
    "/filas/:id/chamar-proxima",
    autenticar,
    somenteAdmin,
    async (req, res) => {

        const filaId = parseInt(req.params.id);

        try {
            const [filasEncontradas] = await db.query(
                "SELECT id, status FROM filas WHERE id = ?",
                [filaId]
            );

            if (filasEncontradas.length === 0) {
                return res.status(404).json({
                    erro: "Fila não encontrada"
                });
            }

            if (filasEncontradas[0].status !== "aberta") {
                return res.status(400).json({
                    erro: "A fila está fechada"
                });
            }

            const [atendimentoAtual] = await db.query(
                `SELECT id, codigo
                 FROM senhas
                 WHERE fila_id = ?
                   AND status = 'chamando'
                 LIMIT 1`,
                [filaId]
            );

            if (atendimentoAtual.length > 0) {
                return res.status(400).json({
                    erro: "Já existe uma senha em atendimento"
                });
            }

            const [senhasAguardando] = await db.query(
                `SELECT
                    id,
                    fila_id AS filaId,
                    usuario_id AS usuarioId,
                    codigo,
                    status
                 FROM senhas
                 WHERE fila_id = ?
                   AND status = 'aguardando'
                 ORDER BY id
                 LIMIT 1`,
                [filaId]
            );

            if (senhasAguardando.length === 0) {
                return res.status(404).json({
                    erro: "Não há senhas aguardando"
                });
            }

            const proximaSenha =
                senhasAguardando[0];

            await db.query(
                `UPDATE senhas
                 SET status = 'chamando'
                 WHERE id = ?`,
                [proximaSenha.id]
            );

            proximaSenha.status = "chamando";

            res.json({
                mensagem: "Próxima senha chamada",
                senha: proximaSenha
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao chamar próxima senha"
            });
        }
    }
);


// Finalizar atendimento - somente administrador
app.post(
    "/filas/:id/finalizar-atendimento",
    autenticar,
    somenteAdmin,
    async (req, res) => {

        const filaId = parseInt(req.params.id);

        try {
            const [filasEncontradas] = await db.query(
                "SELECT id FROM filas WHERE id = ?",
                [filaId]
            );

            if (filasEncontradas.length === 0) {
                return res.status(404).json({
                    erro: "Fila não encontrada"
                });
            }

            const [senhasChamando] = await db.query(
                `SELECT
                    id,
                    fila_id AS filaId,
                    usuario_id AS usuarioId,
                    codigo,
                    status
                 FROM senhas
                 WHERE fila_id = ?
                   AND status = 'chamando'
                 ORDER BY id
                 LIMIT 1`,
                [filaId]
            );

            if (senhasChamando.length === 0) {
                return res.status(404).json({
                    erro: "Não há atendimento em andamento"
                });
            }

            const senhaAtual =
                senhasChamando[0];

            await db.query(
                `UPDATE senhas
                 SET status = 'atendido'
                 WHERE id = ?`,
                [senhaAtual.id]
            );

            senhaAtual.status = "atendido";

            res.json({
                mensagem: "Atendimento finalizado",
                senha: senhaAtual
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao finalizar atendimento"
            });
        }
    }
);


// ======================================================
// STATUS DAS FILAS
// ======================================================

app.get("/filas/:id/status", async (req, res) => {
    const filaId = parseInt(req.params.id);

    try {
        const [filasEncontradas] = await db.query(
            `SELECT
                id,
                nome,
                status,
                proximo_numero AS proximoNumero
             FROM filas
             WHERE id = ?`,
            [filaId]
        );

        if (filasEncontradas.length === 0) {
            return res.status(404).json({
                erro: "Fila não encontrada"
            });
        }

        const fila = filasEncontradas[0];

        const [senhaAtualResultado] =
            await db.query(
                `SELECT codigo
                 FROM senhas
                 WHERE fila_id = ?
                   AND status = 'chamando'
                 ORDER BY id
                 LIMIT 1`,
                [filaId]
            );

        const [aguardando] = await db.query(
            `SELECT codigo
             FROM senhas
             WHERE fila_id = ?
               AND status = 'aguardando'
             ORDER BY id`,
            [filaId]
        );

        res.json({
            fila: fila.nome,
            status: fila.status,

            senhaAtual:
                senhaAtualResultado.length > 0
                    ? senhaAtualResultado[0].codigo
                    : null,

            quantidadeAguardando:
                aguardando.length,

            proximaSenha:
                aguardando.length > 0
                    ? aguardando[0].codigo
                    : null,

            proximoNumero:
                fila.proximoNumero
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar status da fila"
        });
    }
});


// ======================================================
// PAINEL IOT
// ======================================================

// Consultar status do painel
app.get("/paineis/:id/status", async (req, res) => {
    const painelId = parseInt(req.params.id);

    try {
        const [paineisEncontrados] = await db.query(
            `SELECT
                paineis.id,
                paineis.nome AS painel,
                filas.id AS filaId,
                filas.nome AS fila,
                filas.status AS statusFila
             FROM paineis
             INNER JOIN filas
                ON filas.id = paineis.fila_id
             WHERE paineis.id = ?`,
            [painelId]
        );

        if (paineisEncontrados.length === 0) {
            return res.status(404).json({
                erro: "Painel não encontrado"
            });
        }

        const painel =
            paineisEncontrados[0];

        const [senhaAtualResultado] =
            await db.query(
                `SELECT codigo
                 FROM senhas
                 WHERE fila_id = ?
                   AND status = 'chamando'
                 ORDER BY id
                 LIMIT 1`,
                [painel.filaId]
            );

        res.json({
            painel: painel.painel,
            filaId: painel.filaId,
            fila: painel.fila,
            statusFila: painel.statusFila,

            senhaAtual:
                senhaAtualResultado.length > 0
                    ? senhaAtualResultado[0].codigo
                    : null
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar status do painel"
        });
    }
});


// Alterar fila exibida no painel - somente administrador
app.put(
    "/paineis/:id/fila",
    autenticar,
    somenteAdmin,
    async (req, res) => {

        const painelId =
            parseInt(req.params.id);

        const { filaId } = req.body;

        if (!filaId) {
            return res.status(400).json({
                erro: "O ID da fila é obrigatório"
            });
        }

        try {
            const [paineisEncontrados] =
                await db.query(
                    "SELECT id FROM paineis WHERE id = ?",
                    [painelId]
                );

            if (paineisEncontrados.length === 0) {
                return res.status(404).json({
                    erro: "Painel não encontrado"
                });
            }

            const [filasEncontradas] =
                await db.query(
                    "SELECT id FROM filas WHERE id = ?",
                    [filaId]
                );

            if (filasEncontradas.length === 0) {
                return res.status(404).json({
                    erro: "Fila não encontrada"
                });
            }

            await db.query(
                `UPDATE paineis
                 SET fila_id = ?
                 WHERE id = ?`,
                [
                    filaId,
                    painelId
                ]
            );

            res.json({
                mensagem:
                    "Fila do painel atualizada com sucesso",
                painelId,
                filaId
            });

        } catch (erro) {
            console.error(erro);

            res.status(500).json({
                erro: "Erro ao atualizar fila do painel"
            });
        }
    }
);


// ======================================================
// SERVIDOR
// ======================================================

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(
        `SmartQ API rodando em http://localhost:${PORT}`
    );
});