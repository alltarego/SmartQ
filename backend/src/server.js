const express = require("express");
const cors = require("cors");
const db = require("./database");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/", (req, res) => {
    res.json({
        message: "SmartQ API funcionando"
    });
});


app.get("/filas", async (req, res) => {
    try {
        const [filasBanco] = await db.query(
            "SELECT id, nome, status FROM filas"
        );

        res.json(filasBanco);
    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar filas"
        });
    }
});

app.post("/filas", async (req, res) => {
    const { nome } = req.body;

    if (!nome) {
        return res.status(400).json({
            erro: "O nome da fila é obrigatório"
        });
    }

    try {
        const [resultado] = await db.query(
            "INSERT INTO filas (nome, status) VALUES (?, 'aberta')",
            [nome]
        );

        const novaFila = {
            id: resultado.insertId,
            nome: nome,
            status: "aberta"
        };

        res.status(201).json(novaFila);
    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao criar fila"
        });
    }
});

app.post("/filas/:id/senhas", async (req, res) => {
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

        const [resultadoContagem] = await db.query(
            "SELECT COUNT(*) AS quantidade FROM senhas WHERE fila_id = ?",
            [filaId]
        );

        const numero = resultadoContagem[0].quantidade + 1;
        const codigo = `A${String(numero).padStart(3, "0")}`;

        const [resultado] = await db.query(
            "INSERT INTO senhas (fila_id, codigo, status) VALUES (?, ?, 'aguardando')",
            [filaId, codigo]
        );

        const novaSenha = {
            id: resultado.insertId,
            filaId: filaId,
            codigo: codigo,
            status: "aguardando"
        };

        res.status(201).json(novaSenha);
    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao criar senha"
        });
    }
});

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

app.post("/filas/:id/chamar-proxima", async (req, res) => {
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

        const [senhasAguardando] = await db.query(
            `SELECT id, fila_id AS filaId, codigo, status
             FROM senhas
             WHERE fila_id = ? AND status = 'aguardando'
             ORDER BY id
             LIMIT 1`,
            [filaId]
        );

        if (senhasAguardando.length === 0) {
            return res.status(404).json({
                erro: "Não há senhas aguardando"
            });
        }

        const proximaSenha = senhasAguardando[0];

        await db.query(
            "UPDATE senhas SET status = 'chamando' WHERE id = ?",
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
});

app.post("/filas/:id/finalizar-atendimento", async (req, res) => {
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
            `SELECT id, fila_id AS filaId, codigo, status
             FROM senhas
             WHERE fila_id = ? AND status = 'chamando'
             ORDER BY id
             LIMIT 1`,
            [filaId]
        );

        if (senhasChamando.length === 0) {
            return res.status(404).json({
                erro: "Não há atendimento em andamento"
            });
        }

        const senhaAtual = senhasChamando[0];

        await db.query(
            "UPDATE senhas SET status = 'atendido' WHERE id = ?",
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
});

app.get("/filas/:id/status", async (req, res) => {
    const filaId = parseInt(req.params.id);

    try {
        const [filasEncontradas] = await db.query(
            "SELECT id, nome, status FROM filas WHERE id = ?",
            [filaId]
        );

        if (filasEncontradas.length === 0) {
            return res.status(404).json({
                erro: "Fila não encontrada"
            });
        }

        const fila = filasEncontradas[0];

        const [senhaAtualResultado] = await db.query(
            `SELECT codigo
             FROM senhas
             WHERE fila_id = ? AND status = 'chamando'
             ORDER BY id
             LIMIT 1`,
            [filaId]
        );

        const [aguardando] = await db.query(
            `SELECT codigo
             FROM senhas
             WHERE fila_id = ? AND status = 'aguardando'
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
            quantidadeAguardando: aguardando.length,
            proximaSenha:
                aguardando.length > 0
                    ? aguardando[0].codigo
                    : null
        });
    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao buscar status da fila"
        });
    }
});

app.post("/senhas/:id/cancelar", async (req, res) => {
    const senhaId = parseInt(req.params.id);

    try {
        const [senhasEncontradas] = await db.query(
            `SELECT
                id,
                fila_id AS filaId,
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

        await db.query(
            "UPDATE senhas SET status = 'cancelado' WHERE id = ?",
            [senhaId]
        );

        senha.status = "cancelado";

        res.json({
            mensagem: "Senha cancelada com sucesso",
            senha: senha
        });
    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao cancelar senha"
        });
    }
});

app.get("/senhas/:id", async (req, res) => {
    const senhaId = parseInt(req.params.id);

    try {
        const [senhasEncontradas] = await db.query(
            `SELECT
                id,
                fila_id AS filaId,
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

        const painel = paineisEncontrados[0];

        const [senhaAtualResultado] = await db.query(
            `SELECT codigo
             FROM senhas
             WHERE fila_id = ? AND status = 'chamando'
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

app.put("/paineis/:id/fila", async (req, res) => {
    const painelId = parseInt(req.params.id);
    const { filaId } = req.body;

    if (!filaId) {
        return res.status(400).json({
            erro: "O ID da fila é obrigatório"
        });
    }

    try {
        const [paineisEncontrados] = await db.query(
            "SELECT id FROM paineis WHERE id = ?",
            [painelId]
        );

        if (paineisEncontrados.length === 0) {
            return res.status(404).json({
                erro: "Painel não encontrado"
            });
        }

        const [filasEncontradas] = await db.query(
            "SELECT id FROM filas WHERE id = ?",
            [filaId]
        );

        if (filasEncontradas.length === 0) {
            return res.status(404).json({
                erro: "Fila não encontrada"
            });
        }

        await db.query(
            "UPDATE paineis SET fila_id = ? WHERE id = ?",
            [filaId, painelId]
        );

        res.json({
            mensagem: "Fila do painel atualizada com sucesso",
            painelId: painelId,
            filaId: filaId
        });

    } catch (erro) {
        console.error(erro);

        res.status(500).json({
            erro: "Erro ao atualizar fila do painel"
        });
    }
});


const PORT = 3000;

app.listen(PORT, () => {
    console.log(`SmartQ API rodando em http://localhost:${PORT}`);
});