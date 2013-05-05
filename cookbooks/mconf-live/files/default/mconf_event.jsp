<%@ page language="java" contentType="text/html; charset=UTF-8"
  pageEncoding="UTF-8"%>
<%@ include file="mconf_event_conf.jsp"%> 
<%
  request.setCharacterEncoding("UTF-8");
  response.setCharacterEncoding("UTF-8");

  boolean userIsMod = false;
  boolean userValid = false;

  // calls getMeetingInfo to get the number of users in the meeting
  Integer usersNow = 0;
  Document doc = null;
  try {
    String data = getMeetingInfo(meetingID, moderatorPW);
    doc = parseXml(data);
    if (doc.getElementsByTagName("returncode").item(0).getTextContent().trim().equals("SUCCESS")) {
      String tmp = doc.getElementsByTagName("participantCount").item(0).getTextContent().trim();
      usersNow = Integer.parseInt(tmp);
    }
  } catch (Exception e) {
  
    e.printStackTrace();
  }

  // gets the user role and sets userValid if everything is ok
  String role = request.getParameter("role");
  if (role.equals("moderator")) {
    String password = request.getParameter("password");
    if (password.equals(moderatorPW)) {
      userIsMod = true;
      userValid = true;
    }
  } else {
    userIsMod = false;
    userValid = true;
  }

%>

<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
  <script type="text/javascript" src="/js/mconf-wrnp2012.js"></script>
  <link rel="stylesheet" href="/css/mconf-bootstrap.min.css" type="text/css" />
  <link rel="stylesheet" href="/css/style.css" type="text/css" />
  <title>Mconf - Transmissão de evento</title>
</head>

<body>

<%@ include file="bbb_api.jsp"%>
<%!
public String createMeeting(String meetingID, String welcome, String moderatorPassword, 
        String viewerPassword, Integer voiceBridge, String logoutURL, String record, 
        Map<String, String> metadata) {
    String base_url_create = BigBlueButtonURL + "api/create?";

    String welcome_param = "";
    String checksum = "";

    String attendee_password_param = "&attendeePW=ap";
    String moderator_password_param = "&moderatorPW=mp";
    String voice_bridge_param = "";
    String logoutURL_param = "";
    String record_param = "";

    if ((welcome != null) && !welcome.equals("")) {
        welcome_param = "&welcome=" + urlEncode(welcome);
    }

    if ((moderatorPassword != null) && !moderatorPassword.equals("")) {
        moderator_password_param = "&moderatorPW=" + urlEncode(moderatorPassword);
    }

    if ((viewerPassword != null) && !viewerPassword.equals("")) {
        attendee_password_param = "&attendeePW=" + urlEncode(viewerPassword);
    }

    if ((voiceBridge != null) && voiceBridge > 0) {
        voice_bridge_param = "&voiceBridge=" + urlEncode(voiceBridge.toString());
    } else {
        // No voice bridge number passed, so we'll generate a random one for this meeting
        Random random = new Random();
        Integer n = 70000 + random.nextInt(9999);
        voice_bridge_param = "&voiceBridge=" + n;
    }

    if ((logoutURL != null) && !logoutURL.equals("")) {
        logoutURL_param = "&logoutURL=" + urlEncode(logoutURL);
    }

    if ((record != null) && !record.equals("")) {
        record_param = "&record=" + record + getMetaData(metadata);
    }

    //
    // Now create the URL
    //

    String create_parameters = "name=" + urlEncode(meetingID)
        + "&meetingID=" + urlEncode(meetingID) + welcome_param
        + attendee_password_param + moderator_password_param
        + voice_bridge_param + logoutURL_param + record_param;

    Document doc = null;

    try {
        // Attempt to create a meeting using meetingID
        String xml = getURL(base_url_create + create_parameters
            + "&checksum="
            + checksum("create" + create_parameters + salt));
        doc = parseXml(xml);
    } catch (Exception e) {
        e.printStackTrace();
    }

    if (doc.getElementsByTagName("returncode").item(0).getTextContent().trim().equals("SUCCESS")) {
        return meetingID;
    }

    return "Error "
        + doc.getElementsByTagName("messageKey").item(0).getTextContent().trim()
        + ": "
        + doc.getElementsByTagName("message").item(0).getTextContent()
    .trim();
}
%>

<div id="header" class="navbar navbar-fixed-top">
  <div class="navbar-inner">
    <div class="container">
      <div class="pull-left">
        <a class="brand" href="http://mconf.org/events">mconf.org</a>
      </div>
    </div>
  </div>
</div>

<div id="main"><div id="main_content" class="container" style="margin-top: 60px;">

<%
  if (usersNow >= maxUsers && !userIsMod) {
%>

<div class="alert alert-warning">
  Desculpe, o sistema alcançou o número máximo de usuários. Tente novamente mais tarde.
</div>
<a href="javascript: history.back()">Voltar...</a>


<%
  // user invalid == wrong moderator password
  } else if (!userValid) {
%>

<div class="alert alert-error">
  Senha de moderador inválida.
</div>
<a href="javascript: history.back()">Voltar...</a>

<%
  // user invalid == wrong moderator password
  } else if (request.getParameter("username").trim() == "") {
%>

<div class="alert alert-error">
  Você precisa especificar o seu nome para entrar na sessão.
</div>
<a href="javascript: history.back()">Voltar...</a>

<%
  } else {

    // don't let a normal user create the room
    if (!userIsMod) {
      if (!isMeetingRunning(meetingID).equals("true")) {
%>

<div class="alert alert-warning">
  A sessão ainda não foi iniciada. Por favor espere o moderador iniciar a sessão e tente novamente.
</div>
<a href="javascript: history.back()">Voltar...</a>

<%
        return;
      }
    }

    String createResult = createMeeting(meetingID, welcomeMsg, moderatorPW, 
            attendeePW, null, logoutURL, record, recordingMetadata.getMap());
    if (!createResult.equals(meetingID)) {
%>

<div class="alert alert-warning">
  Não foi possível abrir a sala. Por favor, contate o administrador.
</div>
<a href="javascript: history.back()">Voltar...</a>

<%
        return;
    }

    String joinURL = getJoinMeetingURL(request.getParameter("username"),
            meetingID, (userIsMod? moderatorPW: attendeePW));

    if (joinURL.startsWith("http://")) {
      if (request.getParameter("mobile").equals("1")) {
        joinURL = joinURL.replace("http://", "bigbluebutton://");
      }
%>

Se você não for redirecionado, <a href="<%=joinURL%>">clique aqui</a> para entrar.
<br/>
<br/>
<div class="alert alert-success">
  Você já participou da transmissão? <a href="<%=logoutURL%>">Clique aqui</a> para avaliar a experiência de ter acompanhando a transmissão via Mconf.
</div>
<script language="javascript" type="text/javascript">
  window.location.href="<%=joinURL%>";
</script>

<%
    } else { // wrong url
%>

<div class="alert alert-error">
  URL inválida. Verifique seus dados de entrada.
</div>
<a href="javascript: history.back()">Voltar...</a>

<%
    }
  }
%>

</div></div>
</body>
</html>
