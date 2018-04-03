#!/usr/bin/perl

use Net::FTP;
use Net::SMTP;

($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);

$date = sprintf("%d.%02d.%02d_%02d-%02d-%02d",$year+1900,$mon+1,$mday,$hour,$min,$sec);
print "Date is $date\n";

#### Script Variables ####
# DB name for backup, login and pass to MySQL
@databases  = ( "database1",
                "database2",
		"database3" );

$mysql_user = 'root';
$mysql_pass = 'SuperSecretPassword';

# Server name
$server_name = "Server Name";

# Archive name
$archive_name = "$date.tar";

# Temp dir for temporary backup files
$pwd = "/home/_backup";
if (! -d $pwd ) {
        system "mkdir $pwd";
}

# FTP
$ftp_ip = "127.0.0.1";
$ftp_port = "21";
$ftp_login = "user1";
$ftp_pass = "UserPasswordt";
$ftp_dir = "mysql/daily";  # FTP path (without a slash at the end and the beginning)

# Stored amount of backups on the FTP server
$file_num = 10;

# Mail settings
# For Yandex or Gmail with SSL
#$email_to = 'admin@somedomain.com';
#$from = '.......@yandex.ru';
#$smtp_server = 'smtp.yandex.ru';
#$smtp_login = 'yandex_login';
#$smtp_pass = 'pass';
#$smtp_ssl = 1;
#$smtp_port = 465;
#$debug_level = 0;

# For simple mx server
$email_to = 'admin@somedomain.com';
$from = 'noreply@somedomain.com';
$smtp_server = 'mx.somedomain.com';
$smtp_login = 'noreply@somedomain.com';
$smtp_pass = 'MailPassword';
$smtp_method_auth = 'LOGIN'; # maybe CRAM-MD5 or LOGIN
$smtp_ssl = 0;
$smtp_port = 25;
$debug_level = 0;


###########################

sub send_email {
        my $smtp = Net::SMTP->new($smtp_server, Debug=>$debug_level, SSL=>$smtp_ssl, Port=>$smtp_port, Timeout=>30);
        $smtp->auth($smtp_login, $smtp_pass);
        $smtp->mail("$from");
        $smtp->to("$email_to");
        $smtp->data();
        $smtp->datasend("From: $from\n");
        $smtp->datasend("To: Admin\n");
        $smtp->datasend("Subject: (!) Problem with BACKUP on Server $server_name script $0\n");
        $smtp->datasend("Content-Type: text/html; charset=utf-8\n");
        $smtp->datasend("Content-Transfer-Encoding: quoted-printable\n");
        $smtp->datasend("\n");
        $smtp->datasend($err_message);
        $smtp->datasend("\n");
        $smtp->dataend();
        $smtp->quit;
}

# Создаем катаклог, в качестве имени - текущяя дата и задаем переменную с путем
# Create a directory, use the current date as the name, and specify a variable with path
system "mkdir $pwd/'$date'";
$dir_name = "$pwd/'$date'";

# Делаем дамп каждой базы данных
# Dump each DB
foreach $database (@databases){
        print "Backuping database: $database... ";
        $output = `/usr/bin/mysqldump -u$mysql_user -p$mysql_pass $database  > $dir_name/$database.sql 2>>$pwd/err.log`;
        print "Done.\n";
}

# Копируем и перемещаемся в диру с данными для бекапа и создаем их архив
# Move to the dir with data for backup and create their archive
$output = `cd $dir_name && tar -cf $pwd/$archive_name . 2>>$pwd/err.log`;

# Проверяем ошибки при создании дампов баз данных и архива
# Check for errors when creating database and archive
$size = -s "$pwd/err.log";
if ($size > 0) {
        $err_message = "<br>MySQLdump error. Can't create backup database $database<br>";
        open(InFile, "$pwd/err.log") || die;
        while ($line = <InFile>) {
                $err_message .= "<br>$line" ;
        }
        close ( InFile );
        &send_email;
}

eval {
        $ftp = Net::FTP->new("$ftp_ip:$ftp_port", Timeout => 50, Debug => 0, Passive=> 1) || die "Can't connect to ftp server. $!\n";
        $ftp->login("$ftp_login", "$ftp_pass") || die "Can't login to ftp server. $!\n";
        $ftp->mkdir("$ftp_dir");
        $ftp->cwd("$ftp_dir") || die "Path $ftp_dir not found on ftp server. $!\n";
        $ftp->binary();
        $ftp->put("$pwd/$archive_name", "$archive_name") || die "Can't put file to ftp server. $!\n";
        @ftp_files = $ftp->ls(".");
        @ftp_files = sort @ftp_files;
        $file_del = (scalar @ftp_files) - $file_num;
        if($file_del > 0) {
                for($i = 2; $i < $file_del; $i++) {
                        $ftp->delete("@ftp_files[($i)]");
                }
        }
        $ftp->quit();
};

if ($@) {
        $err_message = $@."\n";
        &send_email;
 };

system "rm $pwd/$archive_name";
system "rm -rf $pwd/$date";
system "rm -rf $pwd/err.log";
print  "Cleared. Tasks done.\n";
