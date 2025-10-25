graph TD;

    subgraph "Monde Extérieur (Fiat €)";
        User(Utilisateur) -- "Paie en €" --> OC[OpenCollective];
    end

    subgraph "Niveau 1 : L'Académie des Architectes (Made In Zen)";
        style MIZ_SW fill:#ffd700,stroke:#333,stroke-width:4px
        OC -- "Flux 'Bâtisseur'" --> MIZ_SW["🏛️ Wallet Maître de l'Académie<br/><b>MADEINZEN.SOCIETY</b><br/>(Gère les parts NEẐ des fondateurs)"];
        MIZ_SW -- "Émet les parts NEẐ de fondateur" --> Founder_ZC["Wallet Fondateur<br/><b>ZEROCARD</b>"];
        Founder_ZC -- "Autorise à déployer" --> Deploiement("🚀 Déploie une nouvelle<br/>Constellation Locale");
    end

    Deploiement --> UPlanet_Essaim;

    subgraph "Niveau 2 : UPlanet ZEN 'NAME' (Constellation Locale)";
      UPlanet_Essaim
      subgraph "Organe n°1 : La Réserve Locale";
          style G1W fill:#cde4ff,stroke:#333,stroke-width:2px
          G1W["🏛️ Wallet Réserve<br/><b>UPLANETNAME_G1</b><br/>(Collatéral Ğ1 de l'essaim)"];
      end

      subgraph "Organe n°2 : Les Services Locaux";
          style UW fill:#d5f5e3,stroke:#333,stroke-width:2px
          UW["⚙️ Wallet Services<br/><b>UPLANETNAME</b><br/>(Gère les revenus locatifs locaux)"];
          G1W -- "Collatéralise" --> UW;
          OC -- "Flux 'Locataire'" --> UW;
          UW -- "Crédite Ẑen de service" --> ZenCard["Wallet Utilisateur<br/><b>ZenCard</b>"];
          Script["🤖 Script<br/>ZEN.ECONOMY.sh"] -- "Débite le loyer en Ẑen" --> ZenCard;
          Script -- "Distribue les PAFs locaux" --> InfraWallets["Wallets Capitaine/Armateur Locaux"];
      end
      
      subgraph "Organe n°3 : Le Capital Social Local";
          style SW fill:#fdebd0,stroke:#333,stroke-width:2px
          SW["⭐ Wallet Capital<br/><b>UPLANETNAME_SOCIETY</b><br/>(Gère les parts sociales locales)"];
          G1W -- "Collatéralise" --> SW;
          OC -- "Flux 'Sociétaire Local'" --> SW;
          SW -- "Émet les parts Ẑen" --> ZeroCard["Wallet Sociétaire<br/><b>ZEROCARD</b><br/>(du UPassport)"];
          SW -- "Envoie marqueur<br/>de non-paiement" --> Script;
      end
    end