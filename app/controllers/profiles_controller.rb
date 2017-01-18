class ProfilesController < ApplicationController
    def index
        @queries = Query.where(tag:"routine")
        @fornitori = Fornitore.all
    end
    
    def add_query
        misura = params[:misura]
        stagione = params[:stagione]
        
        if misura.length != 7 || misura.to_i.to_s != misura
            flash.now[:alert] = "Attenzione! Misura non valida. Esempio misura: 2055516"
        else
            if !Query.exists?(misura: misura, stagione: stagione, tag: "routine")
                Query.create(misura: misura, stagione: stagione, tag: "routine")
            end
            flash.now[:success] = "Ricerca inserita con successo!"
        end
        redirect_to profile_path
    end
    
    def remove_query
        if Query.delete(Query.find(params[:id]))
            flash[:success] = "Ricerca rimossa con successo!"
            redirect_to profile_path
        else
            flash[:alert] = "Errore durante la rimozione della ricerca, riprova."
            redirect_to profile_path
        end
    end
    
    def disattiva_fornitore
        if Fornitore.find(params[:id]).update(status:"Disattivato")
            flash[:success] = Fornitore.find(params[:id]).nome + " è stato temporaneamente Disattivato."
        else
            flash[:alert] = "Errore durante la disattivazione di "+Fornitore.find(params[:id]).nome + ", riprova."
        end
        redirect_to profile_path
    end
    
    def attiva_fornitore
        if Fornitore.find(params[:id]).update(status:"Attivo")
            flash[:success] = Fornitore.find(params[:id]).nome + " è ora Attivo."
        else
            flash[:alert] = "Errore durante l'attivazione di "+Fornitore.find(params[:id]).nome + ", riprova."
        end
        redirect_to profile_path
    end
    
    def add_fornitore
        nome = params[:nome]
        indirizzo = params[:indirizzo]
        user_name = params[:user_name]
        password = params[:password]
        Fornitore.create(nome: nome, indirizzo: indirizzo, status: "Attivo", user_name: user_name, password: password)
        redirect_to profile_path
    end
    
    def update_password
        user = User.find(current_user.id)
        password = params[:password]
        password_confirmation = params[:password_confirmation]
        if user.update(password: password, password_confirmation: password_confirmation)
            flash[:success] = "Password aggiornata con successo!"
            log_out
            redirect_to login_path
        else
            flash[:alert] = "La password inserita non è abbastanza lunga o le due password inserite sono diverse"
            redirect_to profile_path
        end
    end
end
