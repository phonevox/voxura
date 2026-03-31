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

<?php
	require("config.php");

	// Create connection
	$con = mysqli_connect(SERVER, DB_USER, DB_PASSWORD, DB_NAME);
	
    if (mysqli_connect_errno())
    {
       echo "Failed to connect to MySQL: " . mysqli_connect_error();
    }
	
	$date_ini = new DateTime();
	$date_end = new DateTime();
	$searchBy = "info1";
	$queue = null;
	$empresa = null;
	$iscsv = isset($_REQUEST['csv']);
	
	if(isset($_POST['date_ini'])){
		$date_ini = date_create_from_format("d/m/Y", $_POST['date_ini']);
	}
	
	if(isset($_POST['date_end'])){
		$date_end = date_create_from_format("d/m/Y", $_POST['date_end']);
	}
	
	if(isset($_POST['searchBy'])){
		$searchBy = $_POST['searchBy'];
	}
	
	if(isset($_POST['queue'])){
		$queue = $_POST['queue'];
	}

	if(isset($_POST['empresa'])) {
		$empresa = $_POST['empresa'];
	}

	$searchQuery = "";
	$searchBy = strtolower($searchBy);
	// @Vitor: Mantendo o padrão da forma que esta, porém isso aqui é bem limitado,
	// Ex: não da pra combinar 2 filtros
	if(!is_null($queue)){
		$searchQuery = "AND " . $searchBy . " LIKE '%" . $queue . "%'";
	}
	if (!is_null($empresa)) {
		$searchQuery = "AND " . $searchBy . " LIKE '%" . $empresa . "%";
	}
				
	$SQL = "SELECT * FROM pesquisa WHERE (DATE(datetime) BETWEEN '" . $date_ini->format("Y-m-d") . "' AND '" . $date_end->format("Y-m-d") . "') " . $searchQuery;
	$result = mysqli_query($con, $SQL);

	function formatarCampoCsv($campo) {
		return '"' . str_replace('"', '""', $campo) . '"';
	}

	if ($iscsv) {
		header('Content-Type: text/csv');
		header('Content-Disposition: attachment; filename="pesquisa-satisfacao.csv"');

		echo '"Empresa","Data","Nivel de Satisfacao","Telefone","Atendente","Nota","Identificador da chamada"' . PHP_EOL;

		if ($result) {
	                while ($row = mysqli_fetch_assoc($result)) {
                        	$date = new DateTime($row["datetime"]);
				$datefmt = formatarCampoCsv($date->format("d/m/Y H:i:s"));
				$empresa = formatarCampoCsv($row['info6']);
				$nivel = formatarCampoCsv($row['info1']);
				$telefone = formatarCampoCsv($row['info2']);
				$atendente = formatarCampoCsv($row['info3']);
				$nota = formatarCampoCsv($row['info4']);
				$identificador = formatarCampoCsv($row['info5']);

				echo "$empresa,$datefmt,$nivel,$telefone,$atendente,$nota,$identificador" . PHP_EOL;
                        }
                }

		exit;
	}
?>

<html lang="pt-br">
    <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf8" />
	<meta charset="utf-8">
        <title>URA</title>
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
		<div class="neo-3mtab"><a href="index.php" style="text-decoration: none;">Dashboard</a></div>
		<div class="neo-3mtabon"><a href="ura_detail.php" style="text-decoration: none;">Relatório Detalhado</a></div>
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
                <td class='neo-table-title-row' style='background:none;'><i class='icon-search icon-white'></i> Relatório de Pesquisa</td>
        </tr>
</div>

<table>

	<div align="center">
        	<form action="ura_detail.php" method="POST" class="form-inline">
				Pesquisar 
				<select id="searchBy" name="searchBy">
						<option value="info1" >Nivel de Satisfação</option>
						<option value="info2" >Telefone</option>
						<option value="info3" >Atendente</option>
						<option value="info4" >Nota</option>
						<option value="info6" >Empresa</option>
				</select>
				
				<?php
					echo '<script> document.getElementById("searchBy").value = "' . $searchBy . '"; </script>';
				?>
				
				<input type="text" size="20" name="queue" value="<?php echo $queue;?>">
		  
				Data Inicial: <i class="icon-calendar"></i>
					<input required id="datepicker1" name="date_ini" type="text" value="<?php echo $date_ini->format("d/m/Y");?>">&nbsp;&nbsp;
				Data Final: <i class="icon-calendar"></i>
					<input required id="datepicker2" name="date_end" type="text" value="<?php echo $date_end->format("d/m/Y");?>">
	 
				<input data-placement='top' data-toggle='tooltip' title='Paginar' type="checkbox" name="full" value="sim" checked>
				<input class="button" type="submit" name="save" value="Consultar">
				<input class="button" type="submit" name="csv" value="Exportar CSV">
			</form>
	</div>
	<tr>
	</tr>

</table>
<br>


        <table align="center" cellspacing="0" cellpadding="0" width="100%" id="neo-table1" >
			<tr style="text-align: center;" class="neo-table-title-row">
				<td class="neo-table-title-row">Empresa</td>
				<td class="neo-table-title-row">Data / Hora&nbsp;</td>
				<td class="neo-table-title-row">Nivel de Satisfacao</td>
				<td class="neo-table-title-row">Telefone</td>
				<td class="neo-table-title-row">Atendente</td>
				<td class="neo-table-title-row">Nota</td>
				<td class="ne-table-title-row">Ação</td>
			</tr>
			
			<?php
				if($result){
					while ($row = mysqli_fetch_assoc($result)) { 
						$date =  new DateTime($row["datetime"]);
						echo "<tr align='center' class='neo-table-data-row'>
									<td class='neo-table-data-row table_data'>" . $row["info6"] . "</td>
									<td class='neo-table-data-row table_data'>" . $date->format("d/m/Y H:i:s") . "</td>
									<td class='neo-table-data-row table_data'>" . $row["info1"] . "</td>
									<td class='neo-table-data-row table_data'>" . $row["info2"] . "</td>
									<td class='neo-table-data-row table_data'>" . $row["info3"] . "</td>
									<td class='neo-table-data-row table_data'>" . $row["info4"] . "</td>
									<td class='neo-table-data-row table_data'><a class='x-neo-table-action' href='recording.php?callid=" . $row['info5'] . "'>Baixar</a></td>
							</tr>";
					}
				}
			?>

        </table>
</div>

</div>
    </body>
</html>
