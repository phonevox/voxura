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
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

define('MYSQL_HOST', 'localhost');
define('MYSQL_USER', 'root');
define('MYSQL_PASS', 'SENHA_DO_DATABASE');
define('AST_MONITOR_PATH', '/var/spool/asterisk/monitor/');

$callid = isset($_GET['callid']) ? $_GET['callid'] : null;

if (!$callid || !preg_match('/^[0-9]+\.[0-9]+$/', $callid)) {
	header('Content-Type: application/json');
	header('Status: 400');
	echo json_encode(
		array(
			"erro" => true,
			"message" => "E preciso informar o parametro callid em um formato valido."
		)
	);
} else {
	$db = mysql_connect(
		MYSQL_HOST,
		MYSQL_USER,
		MYSQL_PASS
	);

	if ($db) {
		mysql_select_db('asteriskcdrdb', $db);
		
		$query = mysql_query("SELECT recordingfile, calldate FROM cdr WHERE uniqueid = '$callid' LIMIT 1");
		$recordingfile = null;
		$calldate = null;

		while ($row = mysql_fetch_array($query, MYSQL_ASSOC)) {
			$recordingfile = $row['recordingfile'];
			$calldate = $row['calldate'];
		}

		mysql_close($db);

		if ($recordingfile && $calldate) {
			// var_dump($calldate);
			// exit;

			if ($recordingfile[0] != '/') {
				$calldate = date_create_from_format('Y-m-d H:i:s', $calldate);
				$year = date_format($calldate, 'Y');
				$month = date_format($calldate, 'm');
				$day = date_format($calldate, 'd');

				$recordingfile = AST_MONITOR_PATH . implode('/', [$year, $month, $day]) . '/' . $recordingfile;
			}

			$pathinfo = pathinfo($recordingfile);
			$ext = $pathinfo['extension'];
			$file = $pathinfo['filename'];

			// var_dump($recordingfile);
			// var_dump($pathinfo);

			$bytes = @file_get_contents($recordingfile);

			if ($bytes === false) {
				header('Content-Type: application/json');
				header('Status: 404');
				echo json_encode(
					array(
						"erro" => true,
						"message" => "Nao foi possivel encontrar a gravacao no caminho '$recordingfile'."
					)
				);
			} else {
				header("Content-Type: audio/$ext");
				header("Content-Disposition: attachment; filename=\"$file.$ext\"");
				echo $bytes;
			}
		} else {
			header('Content-Type: application/json');
			header('Status: 404');
			echo json_encode(
				array(
					"erro" => true,
					"message" => "Nao foi possivel encontrar a gravacao no CDR."
				)
			);
		}
	} else {
		header('Content-Type: application/json');
		header('Status: 500');
		echo json_encode(
			array(
				"erro" => true,
				"message" => "Erro interno, por favor tente novamente mais tarde."
			)
		);
	}
}

?>
