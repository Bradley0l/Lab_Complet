$prenoms = 'Jean','Marie','Karim','Salma','Marion','Sow','Amine','Lea','Yanis','Ines',
           'Hugo','Emma','Nabil','Sara','Adam','Lina','Rayan','Nour','Louis','Jade',
           'Omar','Aya','Paul','Zoe','Ilyes','Manon','Sofiane','Chloe','Bilal','Camille'

$noms = 'Dupont','Martin','Bennani','Simon','Sow','Diallo','Bernard','Traore','Petit',
        'Robert','Cherif','Richard','Alaoui','Moreau','Fofana','Girard','Idrissi',
        'Lefevre','Ndiaye','Roux','Faye','Mercier','Ba','Blanc','Cisse','Garnier'

$services = 'Direction','RH','Finance','IT','Commercial',
            'Marketing','Production','Logistique','Juridique','Support'

# Poids : peu de Direction, beaucoup de Production
$repartition = @{
    Direction=3; RH=25; Finance=40; IT=35; Commercial=90
    Marketing=45; Production=140; Logistique=70; Juridique=12; Support=40
}

$script:compteur = 1

$personnes = foreach ($svc in $services) {
    1..$repartition[$svc] | ForEach-Object {
           [pscustomobject]@{
            Matricule = 'E{0:D5}' -f $script:compteur++
            Prenom    = $prenoms | Get-Random
            Nom       = $noms    | Get-Random
            Service   = $svc
        }
    }
}

$personnes | Export-Csv 'C:\Scripts\employes.csv' -NoTypeInformation -Encoding UTF8

Write-Host "Genere : $($personnes.Count) identites" -ForegroundColor Green

# Combien de doublons de nom exact ?
$doublons = $personnes | Group-Object Prenom, Nom | Where-Object Count -gt 1
Write-Host "Doublons de nom exact : $($doublons.Count) groupes" -ForegroundColor Yellow