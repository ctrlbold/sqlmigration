Function Get-DbaCollationNotIN
{
	param( [string]$Collation, [string]$String, [string]$array )
	return -not (Get-DbaCollationIN -Collation $Collation -String $String -array $array )
}
