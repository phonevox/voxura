<?php
function isAuthenticated() {
return isset($_SESSION['issabel_user']) && isset($_SESSION['issabel_pass']);
}

function redirectToLogin() {
header("Location: ../index.php");
exit;
}

session_name("issabelSession");
session_start();

if (!isAuthenticated()) {
redirectToLogin();
}

?>

<html>
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf8" />
        <title>VOX PANEL</title>
		<link rel="stylesheet" media="screen" type="text/css" href="css/jquery-ui.css" />
       		<link rel="stylesheet" media="screen" type="text/css" href="css/multiple-select.css" />
       		<link rel="stylesheet" media="screen" type="text/css" href="css/bootstrap.min.css" />
		<link rel="stylesheet" media="screen" type="text/css" href="css/styles.css" />
		<link rel="stylesheet" media="screen" type="text/css" href="css/content.css" />
		<link rel="stylesheet" media="screen" type="text/css" href="css/table.css" />
		<script type='text/javascript' src='js/jquery-1.8.3.min.js'></script>
		<script type='text/javascript' src='js/jquery-ui.js'></script>
		<script type='text/javascript' src='js/multiple-select.js'></script>
		<script type='text/javascript' src='js/jquery.ui.datepicker-pt-BR.min.js'></script>
		<script type='text/javascript' src='js/bootstrap.js'></script>
		<script type='text/javascript' src='js/king.js'></script>
		<script type='text/javascript' src='js/highcharts.js'></script>
		<script type='text/javascript' src='js/exporting.js'></script>

    </head>
    <body style="background-color: #f0f0f0;" leftmargin="0" topmargin="0" marginwidth="0" marginheight="0">

    <div>
	<div id="neo-contentbox-leftcolumn">
		<div id="neo-3menubox">  <!-- mostrando contenido del menu tercer nivel -->
		<div class="neo-3mtabon"><a href="index.php" style="text-decoration: none;">Dashboard</a></div>
		<div class="neo-3mtab"><a href="ura_detail.php" style="text-decoration: none;">Relatório Detalhado</a></div>
	</div>
    </div>
         


<div id="neo-contentbox-maincolumn">
        <div class="neo-module-name-left">
</div>


<div class="neo-module-content">

<div class="neo-table-header-row"></div>
<div id='neo-table-ref-table'>
        <table align='center' cellspacing='0' cellpadding='0' width='100%' id='neo-table1' >
        <tr class='neo-table-title-row'>
                <td class='neo-table-title-row' style='background:none;'><i class='icon-signal icon-white'></i> Dashboard</td>
        </tr>
</div>         

<table align='center' cellspacing='0' cellpadding='0' width='100%' id='neo-table1' >

	<tr>
	<td colspan="6">

				      <!--Dashboad-->
        <div id="columns" class="row-fluid">
            <ul id="widget1" class="column ui-sortable unstyled">
                <li id="Widget1" class="widget">
                    <div class="widget-head">
                        <span>Chamadas por Ano</span></div>
                    <div class="widget-content">
                        <iframe id="iframeWidget1" class="widget-iframe" style="overflow: hidden; height: 256px" src="widgets/porano.php">
                        </iframe>
                    </div>
                </li>
            </ul>
            <ul id="widget2" class="column ui-sortable unstyled">
                <li id="Widget2" class="widget">
                    <div class="widget-head">
                        <span>Chamadas hoje</span></div>
                    <div class="widget-content">
                        <iframe id="iframeWidget3" class="widget-iframe" style="overflow: hidden; height: 256px" src="widgets/pordia.php">
                        </iframe>
                    </div>
                </li>
            </ul>
            <ul id="widget3" class="column ui-sortable unstyled">
                <li id="Widget3" class="widget">
                    <div class="widget-head">
                        <span>Chamadas está semana</span></div>
                    <div class="widget-content">
                        <iframe id="iframeWidget2" class="widget-iframe" style="overflow: hidden; height: 256px" src="widgets/porsemana.php">
                        </iframe>
                    </div>
                </li>
                <!--<li id="Widget6" class="widget">
                    <div class="widget-head">
                        <span>Consultas On-Line</span></div>
                    <div class="widget-content">
                        <iframe id="iframeWidget6" class="widget-iframe" style="overflow: hidden; height: 256px" src="widgets/online.php">
                        </iframe>
                    </div>
                </li>-->
            </ul>
        </div>
	<div id="columns" class="row-fluid">	
		<li id="Widget4" class="widget">
                    <div class="widget-head">
                        <span>Chamadas por Hora</span></div>
                    <div class="widget-content">
                        <iframe id="iframeWidget4" class="widget-iframe" style="overflow: hidden; height: 300px" src="widgets/porhora.php">
                        </iframe>
                    </div>
                </li>
		<li id="Widget4" class="widget">
                    <div class="widget-head">
                        <span>Chamadas por Mês</span></div>
                    <div class="widget-content">
                        <iframe id="iframeWidget4" class="widget-iframe" style="overflow: hidden; height: 300px" src="widgets/pormes.php">
                        </iframe>
                    </div>
                </li>
    	</div>





				</td>
			</tr>




        </table>
</div>

</div>
    </body>
</html>

