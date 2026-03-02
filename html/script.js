/* ══════════════════════════════════════════════
   sBanking — JavaScript (NUI + UI Logic)
   ══════════════════════════════════════════════ */

(() => {
    'use strict';

    // ── State ──
    let currentTab = 'deposit';
    let selectedTheme = 'dark';
    let bankBalance = 0;
    let cashBalance = 0;
    let playerName = '';
    let sharedAccounts = [];
    let isCardMode = false;
    let cardOwnerIdentifier = null;
    let cardOwnerName = '';

    // ── DOM References ──
    const app = document.getElementById('app');
    const bankBalanceEl = document.getElementById('bankBalance');
    const cashBalanceEl = document.getElementById('cashBalance');
    const playerNameEl = document.getElementById('playerName');
    const toastContainer = document.getElementById('toastContainer');
    const cardModeBanner = document.getElementById('cardModeBanner');
    const cardOwnerNameBanner = document.getElementById('cardOwnerNameBanner');
    const sharedNavBtn = document.querySelector('[data-tab="shared"]');
    const generateCardSection = document.getElementById('generateCardSection');

    // ══════════════════════════════════════════════
    // UTILITY FUNCTIONS
    // ══════════════════════════════════════════════

    function formatMoney(amount) {
        return '$' + Number(amount).toLocaleString('fr-FR');
    }

    function updateBalanceDisplay() {
        bankBalanceEl.textContent = formatMoney(bankBalance);
        cashBalanceEl.textContent = formatMoney(cashBalance);
        document.getElementById('settingsBank').textContent = formatMoney(bankBalance);
        document.getElementById('settingsCash').textContent = formatMoney(cashBalance);
        document.getElementById('settingsName').textContent = playerName;
    }

    function showToast(message, type = 'info') {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        toastContainer.appendChild(toast);

        setTimeout(() => {
            toast.classList.add('out');
            setTimeout(() => toast.remove(), 300);
        }, 3500);
    }

    function setLoading(btn, loading) {
        if (loading) {
            btn.classList.add('loading');
        } else {
            btn.classList.remove('loading');
        }
    }

    function updateCardModeUI() {
        if (isCardMode) {
            cardModeBanner.classList.remove('hidden');
            cardOwnerNameBanner.textContent = cardOwnerName || 'Inconnu';
            // Masquer l'onglet compte partagé en mode carte
            if (sharedNavBtn) sharedNavBtn.style.display = 'none';
            // Masquer la section de génération de carte
            if (generateCardSection) generateCardSection.style.display = 'none';
        } else {
            cardModeBanner.classList.add('hidden');
            if (sharedNavBtn) sharedNavBtn.style.display = '';
            if (generateCardSection) generateCardSection.style.display = '';
        }
    }

    // ── NUI Fetch ──
    async function nuiFetch(event, data = {}) {
        try {
            const resp = await fetch(`https://sBanking/${event}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            return await resp.json();
        } catch (e) {
            console.log('NUI fetch error:', e);
            return null;
        }
    }

    // ══════════════════════════════════════════════
    // TAB NAVIGATION
    // ══════════════════════════════════════════════

    const navBtns = document.querySelectorAll('.nav-btn');
    const panels = document.querySelectorAll('.tab-panel');

    navBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            const tab = btn.dataset.tab;
            if (tab === currentTab) return;

            // En mode carte, bloquer l'accès au compte partagé
            if (isCardMode && tab === 'shared') return;

            // Update nav
            navBtns.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Update panels
            panels.forEach(p => p.classList.remove('active'));
            const panel = document.getElementById(`panel-${tab}`);
            if (panel) {
                panel.classList.add('active');
            }

            currentTab = tab;

            // Load data for specific tabs
            if (tab === 'deposit' || tab === 'withdraw') loadAccountSelectors();
            if (tab === 'transfer') loadTransferData();
            if (tab === 'shared') loadSharedAccounts();
            if (tab === 'settings') loadPersonalLogs();
        });
    });

    // ══════════════════════════════════════════════
    // ACCOUNT SELECTORS (Deposit / Withdraw)
    // ══════════════════════════════════════════════

    const depositAccountSelect = document.getElementById('depositAccount');
    const withdrawAccountSelect = document.getElementById('withdrawAccount');

    async function loadAccountSelectors() {
        if (isCardMode) {
            // En mode carte, pas de comptes partagés disponibles
            depositAccountSelect.innerHTML = '<option value="personal">💳 Compte de ' + escapeHtml(cardOwnerName || 'Inconnu') + '</option>';
            withdrawAccountSelect.innerHTML = '<option value="personal">💳 Compte de ' + escapeHtml(cardOwnerName || 'Inconnu') + '</option>';
            return;
        }
        const accounts = await nuiFetch('getSharedAccounts');
        sharedAccounts = accounts || [];
        populateAccountSelector(depositAccountSelect);
        populateAccountSelector(withdrawAccountSelect);
    }

    function populateAccountSelector(selectEl) {
        // Keep the personal option, clear the rest
        const currentValue = selectEl.value;
        selectEl.innerHTML = '<option value="personal">💳 Mon compte personnel</option>';

        sharedAccounts.forEach(account => {
            const opt = document.createElement('option');
            opt.value = 'shared_' + account.id;
            opt.textContent = `👥 ${account.name} (${formatMoney(account.balance)})`;
            selectEl.appendChild(opt);
        });

        // Restore previous selection if still valid
        if ([...selectEl.options].some(o => o.value === currentValue)) {
            selectEl.value = currentValue;
        }
    }

    // ══════════════════════════════════════════════
    // DEPOSIT
    // ══════════════════════════════════════════════

    const depositInput = document.getElementById('depositAmount');
    const btnDeposit = document.getElementById('btnDeposit');

    // Quick amounts for deposit
    document.querySelectorAll('#panel-deposit .quick-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const amount = btn.dataset.amount;
            if (amount === 'all') {
                depositInput.value = cashBalance;
            } else {
                depositInput.value = amount;
            }
        });
    });

    btnDeposit.addEventListener('click', async () => {
        const amount = parseInt(depositInput.value);
        if (!amount || amount <= 0) {
            showToast('Veuillez entrer un montant valide', 'error');
            return;
        }

        const accountValue = depositAccountSelect.value;
        setLoading(btnDeposit, true);

        let result;
        if (accountValue === 'personal') {
            result = await nuiFetch('deposit', { amount });
        } else {
            const accountId = parseInt(accountValue.replace('shared_', ''));
            result = await nuiFetch('depositShared', { accountId, amount });
        }

        setLoading(btnDeposit, false);

        if (result && result.success) {
            bankBalance = result.bank;
            cashBalance = result.cash;
            updateBalanceDisplay();
            depositInput.value = '';
            showToast(result.message, 'success');
            // Refresh selectors to update shared balances
            if (accountValue !== 'personal') loadAccountSelectors();
        } else {
            showToast(result ? result.message : 'Erreur de connexion', 'error');
        }
    });

    // ══════════════════════════════════════════════
    // WITHDRAW
    // ══════════════════════════════════════════════

    const withdrawInput = document.getElementById('withdrawAmount');
    const btnWithdraw = document.getElementById('btnWithdraw');

    // Quick amounts for withdraw
    document.querySelectorAll('#panel-withdraw .quick-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const amount = btn.dataset.amount;
            if (amount === 'all') {
                withdrawInput.value = bankBalance;
            } else {
                withdrawInput.value = amount;
            }
        });
    });

    btnWithdraw.addEventListener('click', async () => {
        const amount = parseInt(withdrawInput.value);
        if (!amount || amount <= 0) {
            showToast('Veuillez entrer un montant valide', 'error');
            return;
        }

        const accountValue = withdrawAccountSelect.value;
        setLoading(btnWithdraw, true);

        let result;
        if (accountValue === 'personal') {
            result = await nuiFetch('withdraw', { amount });
        } else {
            const accountId = parseInt(accountValue.replace('shared_', ''));
            result = await nuiFetch('withdrawShared', { accountId, amount });
        }

        setLoading(btnWithdraw, false);

        if (result && result.success) {
            bankBalance = result.bank;
            cashBalance = result.cash;
            updateBalanceDisplay();
            withdrawInput.value = '';
            showToast(result.message, 'success');
            // Refresh selectors to update shared balances
            if (accountValue !== 'personal') loadAccountSelectors();
        } else {
            showToast(result ? result.message : 'Erreur de connexion', 'error');
        }
    });

    // ══════════════════════════════════════════════
    // TRANSFER
    // ══════════════════════════════════════════════

    const transferType = document.getElementById('transferType');
    const transferPlayerSection = document.getElementById('transferPlayerSection');
    const transferSharedSection = document.getElementById('transferSharedSection');
    const transferTarget = document.getElementById('transferTarget');
    const transferSharedTarget = document.getElementById('transferSharedTarget');
    const transferAmount = document.getElementById('transferAmount');
    const btnTransfer = document.getElementById('btnTransfer');

    // Toggle player/shared sections
    transferType.addEventListener('change', () => {
        if (transferType.value === 'player') {
            transferPlayerSection.style.display = '';
            transferSharedSection.style.display = 'none';
        } else {
            transferPlayerSection.style.display = 'none';
            transferSharedSection.style.display = '';
        }
    });

    async function loadTransferData() {
        // Load players
        const players = await nuiFetch('getPlayers');
        transferTarget.innerHTML = '<option value="">Sélectionner un joueur...</option>';
        if (players && Array.isArray(players)) {
            players.forEach(p => {
                const opt = document.createElement('option');
                opt.value = p.id;
                opt.textContent = `[${p.id}] ${p.name}`;
                transferTarget.appendChild(opt);
            });
        }

        if (isCardMode) {
            // En mode carte, masquer l'option "vers compte partagé"
            const sharedOption = transferType.querySelector('option[value="shared"]');
            if (sharedOption) sharedOption.style.display = 'none';
            transferType.value = 'player';
            transferPlayerSection.style.display = '';
            transferSharedSection.style.display = 'none';
        } else {
            const sharedOption = transferType.querySelector('option[value="shared"]');
            if (sharedOption) sharedOption.style.display = '';

            // Load shared accounts for transfer
            const accounts = await nuiFetch('getSharedAccounts');
            transferSharedTarget.innerHTML = '<option value="">Sélectionner un compte...</option>';
            if (accounts && Array.isArray(accounts)) {
                accounts.forEach(a => {
                    const opt = document.createElement('option');
                    opt.value = a.id;
                    opt.textContent = `👥 ${a.name} (${formatMoney(a.balance)})`;
                    transferSharedTarget.appendChild(opt);
                });
            }
        }
    }

    btnTransfer.addEventListener('click', async () => {
        const amount = parseInt(transferAmount.value);
        if (!amount || amount <= 0) {
            showToast('Veuillez entrer un montant valide', 'error');
            return;
        }

        setLoading(btnTransfer, true);
        let result;

        if (transferType.value === 'player') {
            const targetId = parseInt(transferTarget.value);
            if (!targetId) {
                showToast('Veuillez sélectionner un destinataire', 'error');
                setLoading(btnTransfer, false);
                return;
            }
            result = await nuiFetch('transfer', { targetId, amount });
        } else {
            const accountId = parseInt(transferSharedTarget.value);
            if (!accountId) {
                showToast('Veuillez sélectionner un compte partagé', 'error');
                setLoading(btnTransfer, false);
                return;
            }
            result = await nuiFetch('transferToShared', { accountId, amount });
        }

        setLoading(btnTransfer, false);

        if (result && result.success) {
            bankBalance = result.bank;
            cashBalance = result.cash;
            updateBalanceDisplay();
            transferAmount.value = '';
            showToast(result.message, 'success');
        } else {
            showToast(result ? result.message : 'Erreur de connexion', 'error');
        }
    });

    // ══════════════════════════════════════════════
    // SHARED ACCOUNTS
    // ══════════════════════════════════════════════

    const sharedAccountsList = document.getElementById('sharedAccountsList');
    const btnCreateShared = document.getElementById('btnCreateShared');
    const newSharedName = document.getElementById('newSharedName');

    async function loadSharedAccounts() {
        const accounts = await nuiFetch('getSharedAccounts');
        sharedAccounts = accounts || [];
        renderSharedAccounts();
        // Also update deposit/withdraw selectors
        populateAccountSelector(depositAccountSelect);
        populateAccountSelector(withdrawAccountSelect);
    }

    function renderSharedAccounts() {
        if (sharedAccounts.length === 0) {
            sharedAccountsList.innerHTML = `
                <div class="empty-state">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" width="48" height="48">
                        <path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/>
                    </svg>
                    <p>Aucun compte partagé</p>
                </div>`;
            return;
        }

        sharedAccountsList.innerHTML = sharedAccounts.map(account => `
            <div class="shared-card" data-id="${account.id}">
                <div class="shared-card-header">
                    <h4>${escapeHtml(account.name)}</h4>
                    <span class="shared-card-balance">${formatMoney(account.balance)}</span>
                </div>
                <div class="shared-members">
                    ${(account.members || []).map(m => `
                        <span class="member-tag ${m.role === 'owner' ? 'owner' : ''}">
                            ${m.role === 'owner' ? '👑' : '👤'} ${m.identifier.substring(0, 15)}...
                        </span>
                    `).join('')}
                </div>
                <div class="shared-card-actions">
                    <button class="shared-action-btn" onclick="sharedDeposit(${account.id})">Déposer</button>
                    <button class="shared-action-btn" onclick="sharedWithdraw(${account.id})">Retirer</button>
                    <button class="shared-action-btn" onclick="sharedViewLogs(${account.id})">Historique</button>
                    ${account.role === 'owner' ? `
                        <button class="shared-action-btn" onclick="sharedAddMember(${account.id})">+ Membre</button>
                        <button class="shared-action-btn danger" onclick="sharedDelete(${account.id})">Supprimer</button>
                    ` : ''}
                </div>
                <div class="logs-list shared-logs" id="sharedLogs-${account.id}" style="display:none; margin-top:10px;"></div>
            </div>
        `).join('');
    }

    function escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    btnCreateShared.addEventListener('click', async () => {
        const name = newSharedName.value.trim();
        if (!name) {
            showToast('Veuillez entrer un nom de compte', 'error');
            return;
        }

        setLoading(btnCreateShared, true);
        const result = await nuiFetch('createShared', { name });
        setLoading(btnCreateShared, false);

        if (result && result.success) {
            newSharedName.value = '';
            showToast(result.message, 'success');
            loadSharedAccounts();
        } else {
            showToast(result ? result.message : 'Erreur de connexion', 'error');
        }
    });

    // ── Shared Account Operations (global for onclick) ──

    window.sharedDeposit = async function (accountId) {
        showModal('Déposer sur le compte partagé', 'Montant', async (value) => {
            const amount = parseInt(value);
            if (!amount || amount <= 0) {
                showToast('Montant invalide', 'error');
                return;
            }
            const result = await nuiFetch('depositShared', { accountId, amount });
            if (result && result.success) {
                bankBalance = result.bank;
                cashBalance = result.cash;
                updateBalanceDisplay();
                showToast(result.message, 'success');
                loadSharedAccounts();
            } else {
                showToast(result ? result.message : 'Erreur', 'error');
            }
        });
    };

    window.sharedWithdraw = async function (accountId) {
        showModal('Retirer du compte partagé', 'Montant', async (value) => {
            const amount = parseInt(value);
            if (!amount || amount <= 0) {
                showToast('Montant invalide', 'error');
                return;
            }
            const result = await nuiFetch('withdrawShared', { accountId, amount });
            if (result && result.success) {
                bankBalance = result.bank;
                cashBalance = result.cash;
                updateBalanceDisplay();
                showToast(result.message, 'success');
                loadSharedAccounts();
            } else {
                showToast(result ? result.message : 'Erreur', 'error');
            }
        });
    };

    window.sharedAddMember = async function (accountId) {
        showModal('Ajouter un membre', 'ID du joueur en ligne', async (value) => {
            const targetId = parseInt(value);
            if (!targetId) {
                showToast('ID invalide', 'error');
                return;
            }
            const result = await nuiFetch('addMember', { accountId, targetId });
            if (result && result.success) {
                showToast(result.message, 'success');
                loadSharedAccounts();
            } else {
                showToast(result ? result.message : 'Erreur', 'error');
            }
        });
    };

    window.sharedDelete = async function (accountId) {
        showConfirmModal('Supprimer le compte partagé ?', 'Le solde restant sera transféré sur votre compte bancaire.', async () => {
            const result = await nuiFetch('deleteShared', { accountId });
            if (result && result.success) {
                if (result.bank !== undefined) {
                    bankBalance = result.bank;
                    cashBalance = result.cash;
                    updateBalanceDisplay();
                }
                showToast(result.message, 'success');
                loadSharedAccounts();
            } else {
                showToast(result ? result.message : 'Erreur', 'error');
            }
        });
    };

    // ══════════════════════════════════════════════
    // GENERATE BANK CARD
    // ══════════════════════════════════════════════

    const btnGenerateCard = document.getElementById('btnGenerateCard');

    btnGenerateCard.addEventListener('click', async () => {
        showConfirmModal(
            'Obtenir une carte bancaire ?',
            'Cette carte vous permettra d\'accéder à votre compte sur n\'importe quel distributeur. Attention : si quelqu\'un obtient votre carte, il pourra accéder à votre compte !',
            async () => {
                setLoading(btnGenerateCard, true);
                const result = await nuiFetch('generateCard');
                setLoading(btnGenerateCard, false);

                if (result && result.success) {
                    showToast(result.message, 'success');
                } else {
                    showToast(result ? result.message : 'Erreur lors de la génération', 'error');
                }
            }
        );
    });

    // ══════════════════════════════════════════════
    // RENEW BANK CARD
    // ══════════════════════════════════════════════

    const btnRenewCard = document.getElementById('btnRenewCard');

    btnRenewCard.addEventListener('click', async () => {
        showConfirmModal(
            'Renouveler votre carte bancaire ?',
            'Votre ancienne carte sera définitivement invalidée. Si elle a été volée, le voleur ne pourra plus accéder à votre compte. Une nouvelle carte sera générée.',
            async () => {
                setLoading(btnRenewCard, true);
                const result = await nuiFetch('renewCard');
                setLoading(btnRenewCard, false);

                if (result && result.success) {
                    showToast(result.message, 'success');
                } else {
                    showToast(result ? result.message : 'Erreur lors du renouvellement', 'error');
                }
            }
        );
    });

    // ══════════════════════════════════════════════
    // MODALS
    // ══════════════════════════════════════════════

    function showModal(title, placeholder, onConfirm) {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.innerHTML = `
            <div class="modal">
                <h3>${title}</h3>
                <div class="form-group">
                    <div class="input-wrapper">
                        <input type="number" id="modalInput" placeholder="${placeholder}" min="1" style="padding: 14px 16px;">
                    </div>
                </div>
                <div class="modal-actions">
                    <button class="btn-cancel" id="modalCancel">Annuler</button>
                    <button class="btn-confirm" id="modalConfirm">Confirmer</button>
                </div>
            </div>`;
        document.body.appendChild(overlay);

        const input = overlay.querySelector('#modalInput');
        input.focus();

        overlay.querySelector('#modalCancel').addEventListener('click', () => overlay.remove());
        overlay.querySelector('#modalConfirm').addEventListener('click', () => {
            onConfirm(input.value);
            overlay.remove();
        });
        input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
                onConfirm(input.value);
                overlay.remove();
            }
        });
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) overlay.remove();
        });
    }

    function showConfirmModal(title, description, onConfirm) {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.innerHTML = `
            <div class="modal">
                <h3>${title}</h3>
                <p style="color: var(--text-secondary); font-size: 14px; margin-bottom: 16px;">${description}</p>
                <div class="modal-actions">
                    <button class="btn-cancel" id="modalCancel">Annuler</button>
                    <button class="btn-confirm" id="modalConfirm">Confirmer</button>
                </div>
            </div>`;
        document.body.appendChild(overlay);

        overlay.querySelector('#modalCancel').addEventListener('click', () => overlay.remove());
        overlay.querySelector('#modalConfirm').addEventListener('click', () => {
            onConfirm();
            overlay.remove();
        });
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) overlay.remove();
        });
    }

    // ══════════════════════════════════════════════
    // TRANSACTION LOGS
    // ══════════════════════════════════════════════

    const LOG_ICONS = {
        deposit: '⬇️',
        withdraw: '⬆️',
        transfer_out: '➡️',
        transfer_in: '⬅️',
        transfer_to_shared: '🔄',
        shared_deposit: '⬇️',
        shared_withdraw: '⬆️',
        shared_create: '➕',
        shared_add_member: '👤',
        shared_remove_member: '❌',
        card_generate: '💳'
    };

    function getLogAmountClass(type) {
        if (['deposit', 'transfer_in', 'shared_deposit'].includes(type)) return 'positive';
        if (['withdraw', 'transfer_out', 'transfer_to_shared', 'shared_withdraw'].includes(type)) return 'negative';
        return 'neutral';
    }

    function formatLogDate(dateStr) {
        try {
            const d = new Date(dateStr);
            return d.toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
        } catch { return dateStr; }
    }

    function renderLogs(container, logs) {
        if (!logs || logs.length === 0) {
            container.innerHTML = '<div class="empty-state small"><p>Aucune transaction</p></div>';
            return;
        }

        container.innerHTML = logs.map(log => {
            const icon = LOG_ICONS[log.type] || '💳';
            const amountClass = getLogAmountClass(log.type);
            const sign = amountClass === 'positive' ? '+' : amountClass === 'negative' ? '-' : '';
            return `
                <div class="log-item">
                    <div class="log-left">
                        <div class="log-icon ${log.type}">${icon}</div>
                        <div class="log-info">
                            <div class="log-label">${escapeHtml(log.label)}</div>
                            <div class="log-date">${formatLogDate(log.created_at)}</div>
                        </div>
                    </div>
                    <div class="log-amount ${amountClass}">${sign}${formatMoney(log.amount)}</div>
                </div>
            `;
        }).join('');
    }

    async function loadPersonalLogs() {
        const personalLogsEl = document.getElementById('personalLogs');
        const logs = await nuiFetch('getLogs');
        renderLogs(personalLogsEl, logs);
    }

    window.sharedViewLogs = async function (accountId) {
        const logsEl = document.getElementById(`sharedLogs-${accountId}`);
        if (!logsEl) return;

        // Toggle visibility
        if (logsEl.style.display !== 'none') {
            logsEl.style.display = 'none';
            return;
        }

        logsEl.style.display = '';
        logsEl.innerHTML = '<div class="empty-state small"><p>Chargement...</p></div>';
        const logs = await nuiFetch('getSharedLogs', { accountId });
        renderLogs(logsEl, logs);
    };

    // ══════════════════════════════════════════════
    // THEME
    // ══════════════════════════════════════════════

    const themeCards = document.querySelectorAll('.theme-card');
    const btnSaveTheme = document.getElementById('btnSaveTheme');

    themeCards.forEach(card => {
        card.addEventListener('click', () => {
            const theme = card.dataset.theme;
            selectedTheme = theme;

            // Update active state
            themeCards.forEach(c => c.classList.remove('active'));
            card.classList.add('active');

            // Live preview
            document.body.setAttribute('data-theme', theme);
        });
    });

    btnSaveTheme.addEventListener('click', async () => {
        setLoading(btnSaveTheme, true);
        const result = await nuiFetch('saveTheme', { theme: selectedTheme });
        setLoading(btnSaveTheme, false);

        if (result && result.success) {
            showToast('Thème sauvegardé avec succès !', 'success');
        } else {
            showToast(result ? result.message : 'Erreur lors de la sauvegarde', 'error');
        }
    });

    function applyTheme(theme) {
        selectedTheme = theme;
        document.body.setAttribute('data-theme', theme);

        // Update active card
        themeCards.forEach(card => {
            card.classList.toggle('active', card.dataset.theme === theme);
        });
    }

    // ══════════════════════════════════════════════
    // CLOSE BANK
    // ══════════════════════════════════════════════

    document.getElementById('btnClose').addEventListener('click', () => {
        closeBank();
    });

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeBank();
        }
    });

    function closeBank() {
        app.classList.add('hidden');
        isCardMode = false;
        cardOwnerIdentifier = null;
        cardOwnerName = '';
        nuiFetch('closeBank');
    }

    // ══════════════════════════════════════════════
    // NUI MESSAGE LISTENER
    // ══════════════════════════════════════════════

    window.addEventListener('message', (event) => {
        const data = event.data;

        switch (data.action) {
            case 'open':
                bankBalance = data.bank || 0;
                cashBalance = data.cash || 0;
                playerName = data.name || 'Inconnu';
                isCardMode = data.isCardMode || false;
                cardOwnerIdentifier = data.cardOwner || null;
                cardOwnerName = data.cardOwnerName || data.name || '';

                updateBalanceDisplay();
                playerNameEl.textContent = playerName;

                // Apply saved theme
                if (data.theme) {
                    applyTheme(data.theme);
                }

                // Update card mode UI
                updateCardModeUI();

                // Reset to deposit tab
                currentTab = 'deposit';
                navBtns.forEach(b => b.classList.remove('active'));
                panels.forEach(p => p.classList.remove('active'));
                document.querySelector('[data-tab="deposit"]').classList.add('active');
                document.getElementById('panel-deposit').classList.add('active');

                // Clear inputs
                document.querySelectorAll('input[type="number"]').forEach(i => i.value = '');

                app.classList.remove('hidden');

                // Load shared accounts for deposit/withdraw selectors
                loadAccountSelectors();
                break;

            case 'close':
                app.classList.add('hidden');
                isCardMode = false;
                cardOwnerIdentifier = null;
                cardOwnerName = '';
                break;

            case 'notification':
                showToast(data.message, 'info');
                break;
        }
    });

})();
