<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.sql.*,javax.sql.DataSource,javax.naming.InitialContext,java.util.*" %>
<%!
private String html(String text) {
    if (text == null) return "";
    return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
response.setHeader("Cache-Control", "no-store");
String requestId = UUID.randomUUID().toString();
String db = "", dbUser = "", dbTime = "", stage = "JNDI", failure = null;
List<String[]> products = new ArrayList<String[]>();
long start = System.nanoTime();
InitialContext ctx = null;
try {
    ctx = new InitialContext();
    DataSource ds = (DataSource) ctx.lookup("java:comp/env/jdbc/LabDS");
    stage = "CONNECTION";
    try (Connection connection = ds.getConnection()) {
        stage = "QUERY";
        try (PreparedStatement statement = connection.prepareStatement("SELECT current_database(), current_user, current_timestamp")) {
            statement.setQueryTimeout(10);
            try (ResultSet result = statement.executeQuery()) {
                if (result.next()) { db = result.getString(1); dbUser = result.getString(2); dbTime = result.getString(3); }
            }
        }
        try (PreparedStatement statement = connection.prepareStatement("SELECT id, nome, preco FROM lab.produtos ORDER BY id")) {
            statement.setQueryTimeout(10);
            statement.setMaxRows(100);
            try (ResultSet result = statement.executeQuery()) {
                while (result.next()) { products.add(new String[] {result.getString(1),result.getString(2),result.getBigDecimal(3).toPlainString()}); }
            }
        }
    }
    application.log("WASLAB JDBC OK id=" + requestId + " rows=" + products.size());
} catch (Exception exception) {
    failure = stage;
    response.setStatus(503);
    application.log("WASLAB JDBC FAIL id=" + requestId + " stage=" + stage, exception);
} finally {
    if (ctx != null) { try { ctx.close(); } catch (Exception ignored) { } }
}
long elapsed = (System.nanoTime() - start) / 1000000L;
%>
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>WebSphere Lab - JDBC</title>
<style>body{background:#101827;color:#e8eef7;font:16px/1.6 system-ui,sans-serif;margin:0}main{max-width:950px;margin:auto;padding:40px 24px}h1{font-size:36px}section{background:#1a273b;padding:24px;border-radius:12px;margin:20px 0}a{color:#72dcc5}table{width:100%;border-collapse:collapse}th,td{text-align:left;border-bottom:1px solid #38506a;padding:12px}dt{color:#b9c6d9}dd{margin:0 0 12px}code{overflow-wrap:anywhere}.ok{color:#72dcc5}.error{color:#ffb49f}.small{font-size:13px;color:#b9c6d9}</style></head>
<body><main><a href="./">Voltar ao início</a><h1>Consulta via DataSource</h1>
<p>Aplicação → JNDI → pool do WebSphere → driver JDBC → PostgreSQL</p>
<% if (failure == null) { %>
<section><h2 class="ok">Conexão e consulta concluídas</h2><dl><dt>Banco</dt><dd><%= html(db) %></dd><dt>Usuário no banco</dt><dd><%= html(dbUser) %></dd><dt>Horário do banco</dt><dd><%= html(dbTime) %></dd><dt>Tempo total da operação</dt><dd><%= elapsed %> ms</dd></dl></section>
<section><h2>Produtos do laboratório</h2><table><thead><tr><th>ID</th><th>Produto</th><th>Preço (R$)</th></tr></thead><tbody>
<% for (String[] row : products) { %><tr><td><%= html(row[0]) %></td><td><%= html(row[1]) %></td><td><%= html(row[2]) %></td></tr><% } %>
</tbody></table><p><a href="jdbc.jsp">Consultar novamente</a></p></section>
<% } else { %>
<section><h2 class="error">Consulta indisponível</h2><p>Etapa: <strong><%= html(failure) %></strong></p><p>Procure no log <code>WASLAB JDBC FAIL</code> e o identificador abaixo.</p><p>JNDI: recurso/mapeamento. CONNECTION: pool, autenticação ou rede. QUERY: SQL, permissões ou tabela.</p></section>
<% } %>
<p class="small">Identificador: <%= html(requestId) %><br>Recurso: java:comp/env/jdbc/LabDS · Dados limitados a 100 linhas.<br>A conexão é fechada ao terminar e devolvida ao pool. Nenhuma senha está no WAR.</p>
</main></body></html>
