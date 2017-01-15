class ProfilesController < ApplicationController
    def index
        @queries = Query.where(tag:"routine")
        @fornitori = Fornitore.all
    end
    
    def add_query
        misura = params[:misura]
        stagione = params[:stagione]
        
        if misura.length != 7 || misura.to_i.to_s != misura
            flash[:alert] = "Attenzione! Misura non valida. Esempio misura: 2055516"
        else
            if !Query.exists?(misura: misura, stagione: stagione, tag: "routine")
                Query.create(misura: misura, stagione: stagione, tag: "routine")
            end
            flash[:success] = "Ricerca inserita con successo!"
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
        Fornitore.find(params[:id]).update(status:"Disattivato")
        redirect_to profile_path
    end
    
    def attiva_fornitore
        Fornitore.find(params[:id]).update(status:"Attivo")
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
end
