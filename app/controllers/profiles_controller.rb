require 'csv'
class ProfilesController < ApplicationController
    def index
        @queries = Search.where(tag:"routine")
        @fornitori = Fornitore.all
    end
    
    def add_query
        misura = params[:misura]
        stagione = params[:stagione]
        
        if misura.length != 7 || misura.to_i.to_s != misura
            flash.now[:alert] = "Attenzione! Misura non valida. Esempio misura: 2055516"
        else
            if !Search.exists?(misura: misura, stagione: stagione, tag: "routine")
                Search.create(misura: misura, stagione: stagione, tag: "routine")
            end
            flash.now[:success] = "Ricerca inserita con successo!"
        end
        redirect_to profile_path
    end
    
    def remove_query
        if Search.delete(Search.find(params[:id]))
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
    
    
    def magazzino_index

        Magazzino.delete_all
        text = File.read("2.csv")
        csv = CSV.parse(text, :headers => true)
        csv.each do |row|
          row = row.to_hash.with_indifferent_access
          pneu = Magazzino.create!(row.to_hash.symbolize_keys)
          pneu.update(user_id: current_user.id)
        end

        @pneumatici_magazzino = Magazzino.where(user_id: current_user.id)
    end
    
    def magazzino_new 
        @magazzino = Magazzino.new
        @pneumatico_test = Magazzino.last
    end
    
    def magazzino_create
        @pneumatico = Magazzino.create!(magazzino_params)
        
        @pneumatico.update(user_id: current_user.id)
        
        redirect_to :magazzino
    end
    
    def magazzino_edit
        @pneumatico = Magazzino.find(params[:params])
        
        if @pneumatico.user_id != current_user.id 
            redirect_to :magazzino
        end
    end
    
    def magazzino_update
        puts params[:params]
        pneumatico = Magazzino.find(params[:id])
        if pneumatico.nil?
            redirect_to :magazzino
        else
            if params[:params] == "pneumatici_disponibili"
            
                
                
                pezzi = params[:pneumatici_disponibili]
                
                pneumatico.update(pneumatici_disponibili: pezzi)
                
               
            elsif params[:params] == "ubicazione"
                ubicazione = params[:ubicazione]
            
                pneumatico.update(ubicazione: ubicazione)
                
                
                    
            end
            
            redirect_to edit_magazzino_path(pneumatico.id)
        end
    end
    
   
    
    def magazzino_delete
        Magazzino.find(params[:id]).delete
        redirect_to :magazzino
    end
    
    
private
    
    def magazzino_params
        params.require(:magazzino).permit(:pneumatico, :corda , :serie, :cerchio, :misura, :cod_carico, :cod_vel, :marca, :modello, :dot, :battistrada, :lotto, :shore, :targa, :cliente, :rete, :scaffale, :ubicazione, :pneumatici_disponibili, :stagione)
    end
end


