#!/usr/bin/php -q
<?php

require_once('/var/lib/asterisk/agi-bin/phpagi.php');
$agi = new AGI();

// Função para conectar ao banco de dados usando PDO
function connect_db() {
    $dsn = 'mysql:host=localhost;dbname=avaliacao;charset=utf8';
    $username = 'root';
    $password = 'SENHA_DO_DATABASE';

    try {
        $pdo = new PDO($dsn, $username, $password, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, // Modo de erro para exceções
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC, // Modo de fetch
        ]);
        return $pdo;
    } catch (PDOException $e) {
        die('Erro ao conectar ao banco de dados: ' . $e->getMessage());
    }
}

$pdo = connect_db();

// Parâmetros recebidos pelo script
$separacao = explode("-", $argv[4]);
$atendedor = $separacao[0];
$agi->set_variable('atendente', $atendedor);

$satisfacao = $argv[1];
$callerid = $argv[2];
$nota = $argv[3];
$operador = $atendedor;
$uniqueid = $argv[5];
$empresa = $argv[6];

// Remover prefixos específicos do operador
$vowels = ['SIP/', 'IAX2/', 'IAX/', 'Agent/'];
$operador_number = str_replace($vowels, '', $operador);
$atendedor = $operador_number;

// Query de inserção usando prepared statements
$query = "INSERT INTO pesquisa (datetime, info1, info2, info3, info4, info5, info6) 
          VALUES (NOW(), :satisfacao, :callerid, :atendedor, :nota, :uniqueid, :empresa)";

try {
    $stmt = $pdo->prepare($query);
    $stmt->execute([
        ':satisfacao' => $satisfacao,
        ':callerid'   => $callerid,
        ':atendedor'  => $atendedor,
        ':nota'       => $nota,
        ':uniqueid'   => $uniqueid,
        ':empresa'    => $empresa,
    ]);

    $agi->verbose("Dados inseridos com sucesso na tabela 'pesquisa'.", 1);
} catch (PDOException $e) {
    $agi->verbose("Erro ao inserir dados: " . $e->getMessage(), 1);
}
