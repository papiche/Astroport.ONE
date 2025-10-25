graph TD;

    subgraph "Monde Extérieur (Fiat €)";
        User(Utilisateur) -- "Paie en €" --> OC[OpenCollective];
        OC -- "Expense PAF Burn" --> Armateur[Armateur €];
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
          style G1W fill:#cde4ff,stroke:#333,stroke-width:4px
          G1W["🏛️ Wallet Réserve<br/><b>UPLANETNAME_G1</b><br/>(Collatéral Ğ1 de l'essaim)"];
      end

      subgraph "Organe n°2 : Les Services Locaux";
          style UW fill:#d5f5e3,stroke:#333,stroke-width:2px
          UW["⚙️ Wallet Services<br/><b>UPLANETNAME</b><br/>(Gère les revenus locatifs locaux)"];
          G1W -- "Collatéralise & Initialise" --> UW;
          OC -- "Flux 'Locataire'" --> UW;
          UW -- "Crédite Ẑen de service" --> MULTIPASS["Wallet MULTIPASS<br/><b>CAPTAIN.MULTIPASS</b><br/>(1Ẑ/semaine)"];
      end
      
      subgraph "Organe n°3 : Le Capital Social Local";
          style SW fill:#fdebd0,stroke:#333,stroke-width:2px
          SW["⭐ Wallet Capital<br/><b>UPLANETNAME_SOCIETY</b><br/>(Gère les parts sociales locales)"];
          G1W -- "Collatéralise & Initialise" --> SW;
          OC -- "Flux 'Sociétaire Local'" --> SW;
          SW -- "Émet les parts Ẑen" --> ZenCard["Wallet Sociétaire<br/><b>CAPTAIN.ZENCARD</b><br/>(50Ẑ parts sociales)"];
      end

      subgraph "Organe n°4 : Infrastructure Opérationnelle";
          style NODE fill:#ffebcd,stroke:#8b4513,stroke-width:2px
          NODE["🖥️ Wallet NODE<br/><b>secret.NODE.dunikey</b><br/>(Armateur - Machine)"];
          G1W -- "Initialise" --> NODE;
          ZenCard -- "Apport Capital Machine<br/>(une seule fois)" --> NODE;
      end

      subgraph "Organe n°5 : Portefeuilles Coopératifs";
          style CASH fill:#e8f5e8,stroke:#2e7d32,stroke-width:2px
          style RND fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
          style ASSETS fill:#fff3e0,stroke:#f57c00,stroke-width:2px
          style IMPOT fill:#fce4ec,stroke:#c2185b,stroke-width:2px
          
          CASH["💰 UPLANETNAME_CASH<br/>(Trésorerie 1/3)"];
          RND["🔬 UPLANETNAME_RND<br/>(R&D 1/3)"];
          ASSETS["🌳 UPLANETNAME_ASSETS<br/>(Actifs 1/3)"];
          IMPOT["🏛️ UPLANETNAME_IMPOT<br/>(Fiscalité TVA+IS)"];
          
          G1W -- "Initialise" --> CASH;
          G1W -- "Initialise" --> RND;
          G1W -- "Initialise" --> ASSETS;
          G1W -- "Initialise" --> IMPOT;
      end
    end

    subgraph "Niveau 3 : Flux Économiques Automatisés";
        
        subgraph "Collecte Revenus (Hebdomadaire)";
            MULTIPASS -- "1Ẑ HT + 0.2Ẑ TVA" --> CAPTAIN_TOTAL["Captain Total<br/>(Revenus locatifs)"];
            ZenCard -- "4Ẑ HT + 0.8Ẑ TVA" --> CAPTAIN_TOTAL;
            CAPTAIN_TOTAL -- "TVA (20%)" --> IMPOT;
        end

        subgraph "Paiement PAF (Hebdomadaire - ZEN.ECONOMY.sh)";
            CAPTAIN_TOTAL -- "14Ẑ PAF" --> NODE;
            CAPTAIN_TOTAL -- "28Ẑ Rémunération" --> CAPTAIN_TOTAL;
            CASH -- "PAF Solidarité<br/>(si CAPTAIN insuffisant)" --> NODE;
        end

        subgraph "Burn & Conversion (4-semaines)";
            NODE -- "56Ẑ Burn (4*PAF)" --> G1W;
            G1W -- "API OpenCollective<br/>56€ Expense" --> OC;
            OC -- "Virement SEPA" --> Armateur;
        end

        subgraph "Allocation Coopérative (3x1/3)";
            CAPTAIN_TOTAL -- "Surplus Net" --> COOPERATIVE_SPLIT["Répartition<br/>Coopérative"];
            COOPERATIVE_SPLIT -- "1/3" --> CASH;
            COOPERATIVE_SPLIT -- "1/3" --> RND;
            COOPERATIVE_SPLIT -- "1/3" --> ASSETS;
            COOPERATIVE_SPLIT -- "IS (25%)" --> IMPOT;
        end
    end

    subgraph "Scripts & Automatisation";
        style SCRIPTS fill:#f0f0f0,stroke:#666,stroke-width:1px
        SCRIPT_ECONOMY["🤖 ZEN.ECONOMY.sh<br/>(Paiement PAF + Burn)"];
        SCRIPT_COOP["🤖 ZEN.COOPERATIVE.3x1-3.sh<br/>(Allocation 3x1/3)"];
        SCRIPT_NOSTR["🤖 NOSTRCARD.refresh.sh<br/>(Collecte MULTIPASS)"];
        SCRIPT_PLAYER["🤖 PLAYER.refresh.sh<br/>(Collecte ZEN Cards)"];
        SCRIPT_OFFICIAL["🤖 UPLANET.official.sh<br/>(Émission Ẑen)"];
        SCRIPT_INIT["🤖 UPLANET.init.sh<br/>(Initialisation)"];
        
        SCRIPT_ECONOMY -.-> NODE;
        SCRIPT_ECONOMY -.-> G1W;
        SCRIPT_COOP -.-> CASH;
        SCRIPT_COOP -.-> RND;
        SCRIPT_COOP -.-> ASSETS;
        SCRIPT_NOSTR -.-> MULTIPASS;
        SCRIPT_PLAYER -.-> ZenCard;
        SCRIPT_OFFICIAL -.-> SW;
        SCRIPT_INIT -.-> G1W;
    end

    %% Styling
    classDef success fill:#d4edda,stroke:#155724,color:#155724
    classDef error fill:#f8d7da,stroke:#721c24,color:#721c24
    classDef process fill:#d1ecf1,stroke:#0c5460,color:#0c5460
    classDef decision fill:#fff3cd,stroke:#856404,color:#856404
    classDef payment fill:#e8deee,stroke:#4a2d7e,color:#4a2d7e
    classDef allocation fill:#deedf7,stroke:#0b5394,color:#0b5394
    classDef burn fill:#ffe6e6,stroke:#d32f2f,color:#d32f2f

    class CAPTAIN_TOTAL,COOPERATIVE_SPLIT process
    class NODE,G1W,UW,SW payment
    class CASH,RND,ASSETS,IMPOT allocation
    class Armateur,OC burn
