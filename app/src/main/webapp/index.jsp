<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" import="java.util.UUID,java.time.Instant" %>
<%!
private String esc(String value) {
    if (value == null) return "";
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
}
%>
<%
response.setHeader("Cache-Control", "no-store");
String csrf;
synchronized(session) {
    csrf = (String) session.getAttribute("csrf");
    if (csrf == null) { csrf = UUID.randomUUID().toString(); session.setAttribute("csrf", csrf); }
}
if ("POST".equals(request.getMethod())) {
    if (!csrf.equals(request.getParameter("csrf"))) { response.sendError(403); return; }
    String action = request.getParameter("action");
    if ("log".equals(action)) {
        String event = UUID.randomUUID().toString();
        application.log("WASLAB evento didatico id=" + event);
        session.setAttribute("notice", "Mensagem enviada ao log. Procure WASLAB e o identificador " + event);
    } else if ("reset".equals(action)) {
        synchronized(session) { session.setAttribute("visits", Integer.valueOf(0)); }
        session.setAttribute("notice", "Contador zerado. Esta nova visita sera a numero 1.");
    }
    response.sendRedirect(request.getContextPath() + "/");
    return;
}
int visits;
String marker;
String notice;
synchronized(session) {
    Integer old = (Integer) session.getAttribute("visits");
    visits = old == null ? 1 : old.intValue() + 1;
    session.setAttribute("visits", Integer.valueOf(visits));
    marker = (String) session.getAttribute("marker");
    if (marker == null) { marker = UUID.randomUUID().toString().substring(0,8); session.setAttribute("marker", marker); }
    notice = (String) session.getAttribute("notice");
    session.removeAttribute("notice");
}
Runtime runtime = Runtime.getRuntime();
long mb = 1024L * 1024L;
%>
<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>WebSphere Lab</title>
<style>
body{margin:0;background:#101827;color:#e8eef7;font:16px/1.6 system-ui,sans-serif}main{max-width:980px;margin:auto;padding:48px 24px}h1{font-size:40px;margin:8px 0}h2{font-size:21px}.label{color:#72dcc5;text-transform:uppercase;letter-spacing:2px;font-size:12px}.intro{color:#b9c6d9}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:20px;margin-top:28px}section{background:#1a273b;border:1px solid #31435e;border-radius:14px;padding:24px}.number{font-size:56px;color:#72dcc5;margin:0}dt{color:#a7bbd5;margin-top:12px}dd{margin:0;overflow-wrap:anywhere}button,a.button{display:inline-block;background:#72dcc5;color:#101827;border:0;border-radius:7px;padding:10px 16px;font:inherit;cursor:pointer;text-decoration:none;margin:6px 6px 6px 0}a{color:#8fe5f5}form{display:inline}.notice{padding:16px;border:1px solid #72dcc5;border-radius:8px;overflow-wrap:anywhere}.small{font-size:13px;color:#b9c6d9}code{overflow-wrap:anywhere}
</style></head><body><main>
<div class="label">IBM WebSphere Traditional · Laboratório 01</div>
<h1>WebSphere na prática.</h1>
<p class="intro">Deploy, sessões, JVM, logs e consultas ao PostgreSQL pelo DataSource do servidor.</p>
<p><a class="button" href="jdbc.jsp">Consultar banco via JDBC</a></p>
<% if (notice != null) { %><p class="notice"><%= esc(notice) %></p><% } %>
<div class="grid"><section><h2>Sessão do navegador</h2><p class="number"><%= visits %></p><p>visitas nesta sessão</p>
<p class="small">Identificador didático: <%= esc(marker) %><br>Inatividade máxima: <%= session.getMaxInactiveInterval() / 60 %> minutos.</p>
<a class="button" href="./">Nova visita</a>
<form method="post" action=""><input type="hidden" name="csrf" value="<%= esc(csrf) %>"><button name="action" value="reset">Zerar contador</button></form>
<p class="small">Abra uma janela anônima para observar uma sessão diferente. Abas do mesmo navegador normalmente compartilham a sessão.</p></section>
<section><h2>Ambiente de execução</h2><dl>
<dt>Servidor</dt><dd><%= esc(application.getServerInfo()) %></dd>
<dt>Java</dt><dd><%= esc(System.getProperty("java.version")) %></dd>
<dt>Hostname do contêiner</dt><dd><%= esc(System.getenv("HOSTNAME")) %></dd>
<dt>Context root</dt><dd><%= esc(request.getContextPath()) %></dd>
<dt>Horário UTC</dt><dd><%= Instant.now().toString() %></dd>
</dl></section>
<section><h2>Memória da JVM</h2><dl><dt>Heap usado (aproximado)</dt><dd><%= (runtime.totalMemory()-runtime.freeMemory())/mb %> MiB</dd><dt>Heap alocado</dt><dd><%= runtime.totalMemory()/mb %> MiB</dd><dt>Heap máximo</dt><dd><%= runtime.maxMemory()/mb %> MiB</dd></dl><p class="small">Valores da JVM inteira, compartilhada com o servidor e outras aplicações. Não representam toda a memória do contêiner.</p></section>
<section><h2>Diagnóstico</h2><form method="post" action=""><input type="hidden" name="csrf" value="<%= esc(csrf) %>"><button name="action" value="log">Gerar mensagem no log</button></form><p><a href="health.jsp" target="_blank" rel="noopener">Consultar health.jsp (JSON)</a></p><p class="small">O endpoint confirma que esta página responde. Ainda não verifica banco de dados nem dependências externas.</p></section></div>
<p class="small">WebSphere Lab 1.1 · Aplicação didática. Configurações e sessões do WebSphere não têm persistência garantida quando o contêiner é recriado.</p>
</main></body></html>
