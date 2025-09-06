let
  emmberkat = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdi3BSg+IH8cjyB3BaqxHkL0yuiMT7wb1Wc5rxUZMJ5uIwjMjO8IPRBh07nF4oAlUJQBUu5VLBXT7pKq3BkMHkOBO2qqjgNaXy2r3CPlRkky8M6f/iXrd7E1E8NpL3qARaP7Wke+SmJrlrmN+luvyypZUahcebh5dctkWdz/s6nQ3DY1bc3OmUCSCMj+jmFdnQ/2fwYjwEjkSYYO4iYDygzXhkyWK6eRG2y1/aMTHESPyY3716vhTPMVry9/dkDijURvzpTvdrg/9wXMVd0Xt5HXCcJvhyXkedLd9IUt09VaslTnJ2XWc1utYZA4X0F2tyGyGaFAIsGZ1krcl0r13f";

  crystal = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBBBWOb9L5iylPNJXCYONM0Da0ZrmNR51vRKJjnPTbzn0h4KsLmU18dhxptHEZf40DUFosIa8Kugg17Kac5UGFy2yfKkr7vKy7Ai29Y2iPXcoxZ1wdRJlTl0QJZR6RrBQI6bOa/s06qBiD06eskT3d0EzmpkL0rx7HcEudVD4B1H2nTjkAIfeTs9CY4JAvX8VfvvmRxAWpHg6wctycKT9+bTFWicKy7XnPbwaKehgTDISBLMJmIyZ4bVWejUYqajbW59JM1MY5/B0uMO2N70ZCjYELpw6RW5h/OuUAIoH/5puJKnz04dFXLO0pPDvDZJ1O1bvv9ZBADAU3KUXk3qferyAGtwHe2AAUzUyb/kF2KjDSXQW7jvxNTi5G7FLgnxSrAgRmN1aZgLCWtJTuZCSc+z/HbUkUlfX6GwTU/br1qqoUj0HTdUSiBt2hOt+AhoNa8pAEjSmzYLAIwZ7S3cZcJBJsgO4WvjRhxq30m7d6sphaWhwxS18dz5ViPMpnRqlcSSz79xvCPfGftvzAh1Dbc1eyAiyoSTB8iCpLz9nzVLzASw0TQAXDgpMSip6+1XmnRvGZBXKDKKwlve2TX/sP2iqx4Iqb6GU67yGn26AU2rS9+NZATkKCtGVuetgSXNDqpAe25ToMDKaiNplVosUQga9uTwehzMk2NbIbYQfwZw==";

in
{
  "syncthing/key.age" = {
    publicKeys = [
      emmberkat
      crystal
    ];
    armor = true;
  };
  "syncthing/cert.age" = {
    publicKeys = [
      emmberkat
      crystal
    ];
    armor = true;
  };
  "restic/environment.age" = {
    publicKeys = [
      emmberkat
      crystal
    ];
    armor = true;
  };
  "restic/password.age" = {
    publicKeys = [
      emmberkat
      crystal
    ];
    armor = true;
  };
}
