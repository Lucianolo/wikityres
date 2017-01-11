require "selenium-webdriver"
require "watir"
require 'thread'
require 'nokogiri'
require 'mechanize'
class WelcomeController < ApplicationController
  
  skip_before_filter :require_login, :only => :cron_job
  

  def search 
    @marche = []
    Pneumatico.all.each do |item|
      @marche.push(item.marca) unless @marche.include?(item.marca)
    end
    
    @marche_pneumatici = []
    file_pneumatici = File.open('marche_pneumatici.html.erb','r')
    document_pneumatici = Nokogiri::HTML(file_pneumatici)
    document_pneumatici.css('select option').each do |option|
      @marche_pneumatici.push option.text
    end
    file_pneumatici.close
    
  end
  
  
  
  def index
    @results = {}
    max_results = 300
  
    query = params[:misura].to_i
    
    # Per ora tolgo la marca
    
    #marca = params[:marca]
    
    marca = ""
    stagione = params[:stagione]
    if params[:misura].to_i.to_s != params[:misura] || params[:misura].length != 7
      flash[:alert] = "Ricerca non valida"
      redirect_to root_path
    else
      query_list = [query]
      
      puts query_list
      tmp_misura = query.to_s[0..2]+"/"+query.to_s[3..4]
      tmp_raggio = query.to_s[5..-1]
      
      puts tmp_misura
      puts tmp_raggio
      if Query.exists?(misura: query.to_s , stagione: stagione) || Query.exists?(misura: query.to_s, stagione: "Tutte")
        
        puts "La query esiste già"
        if stagione != "Tutte"
          if marca != ""
            
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?) AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni", marca).order(:prezzo_netto)
          else
            
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?)", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni").order(:prezzo_netto)
          end
        else
          if marca != ""
            
            @res = Pneumatico.where("misura like ? AND raggio like ?  AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", marca).order(:prezzo_netto)
          else
            
            @res = Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).order(:prezzo_netto)
          end
        end
        puts @res.inspect
      else
        Watir.default_timeout = 60
        
        Selenium::WebDriver::PhantomJS.path = Rails.root.join('bin','phantomjs').to_s
        populate(query_list, max_results, stagione)
        if stagione != "Tutte"
          if marca != ""
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?) AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni", marca).order(:prezzo_netto)
          else
            @res = Pneumatico.where("misura like ? AND raggio like ? AND (stagione like ?  OR stagione like ?)", "%#{tmp_misura}%","%#{tmp_raggio}%", stagione, "4 Stagioni").order(:prezzo_netto)
          end
        else
          if marca != ""
            @res = Pneumatico.where("misura like ? AND raggio like ?  AND marca like ?", "%#{tmp_misura}%","%#{tmp_raggio}%", marca).order(:prezzo_netto)
          else
            @res = Pneumatico.where("misura like ? AND raggio like ?", "%#{tmp_misura}%","%#{tmp_raggio}%" ).order(:prezzo_netto)
          end
        end
        
        Query.create(misura: query.to_s , stagione: stagione)
      end  
    end
  end
  
  def cron_job
    query_list = []
    Query.where(tag: "routine").each do |query|
      query_list.push(query.misura)
    end
    Selenium::WebDriver::PhantomJS.path = Rails.root.join('bin','phantomjs').to_s
    puts query_list
    #query_list = ["2055516", "1956515", "1856515","1956015", "1756514", "1756515"]
    populate(query_list, 300)
    redirect_to :root
  end
  
  
private

  def populate(query_list , max_results, stagione = "Tutte")
    if query_list.length > 1
      Pneumatico.delete_all
      Query.where(tag: nil).delete_all
    end
    
    @fintyre = "http://b2b.fintyre.it/fintyre2/main?TASK=Precercaarticoli&OUTPAGE=/ordini/ricerche/ricercaArticoli.jsp&ERRPAGE=/common/error.jsp"
    @farnesepneus = "http://www.b2b.farnesepneus.it/check-prices"
    @centrogomme = "http://ordini.centrogomme.com/views/B2BCG/BB.view.php?page=ricerca"
    @cdp = "http://www.cdpgroupspa.com/"
    @multitires = "http://multitires.autotua.it/interna.asp"
    @maxtyre = "http://web.maxtyre.it/"
    @pendingomme = "http://www.pendingomme.it/login"
    
    fornitori = []
    Fornitore.where(status: "Attivo").each do |f|
      fornitori.push(f.nome)
    end
    
    query_list.each do |query|
      puts query
      threads = []
      
      # PENDINGOMME.IT
      if fornitori.include? "PendinGomme"
        threads << Thread.new {
          begin
            search_pendingomme(query,stagione,max_results)
          ensure
            ActiveRecord::Base.connection_pool.release_connection
          end
        }
      end
      
      # FARNESEPNEUS.IT
      if fornitori.include? "FarnesePneus"
        threads << Thread.new {
          begin
            search_farnese(query,stagione,max_results)
          ensure
          #guarantee that the thread is releasing the DB connection after it is done
            ActiveRecord::Base.connection_pool.release_connection
          end
        }
      end
        
      # FINTYRE.IT
      if fornitori.include? "Fintyre"
        threads << Thread.new {
          begin
            search_fintyre(query,stagione,max_results)
          ensure
          #guarantee that the thread is releasing the DB connection after it is done
            ActiveRecord::Base.connection_pool.release_connection
          end
        }
      end
  
      # CENTRO GOMME
      if fornitori.include? "CentroGomme"
        threads << Thread.new {
          begin
            search_centrogomme(query,stagione,max_results)
          ensure
          #guarantee that the thread is releasing the DB connection after it is done
            ActiveRecord::Base.connection_pool.release_connection
          end
        }
      end
      
      # MULTITYRES
      if fornitori.include? "MultiTyre"
        threads << Thread.new {
          begin
            search_multityre(query, stagione, max_results)
          ensure
          #guarantee that the thread is releasing the DB connection after it is done
            ActiveRecord::Base.connection_pool.release_connection
          end
        }
      end
        
      # MAXTYRE
      if fornitori.include? "MaxTyre"
        threads << Thread.new {
          begin
            search_maxtyre(query, stagione, max_results)
          ensure
          #guarantee that the thread is releasing the DB connection after it is done
            ActiveRecord::Base.connection_pool.release_connection
          end
        }
      end
      threads.each(&:join)
      
     
    end

  end

  def sureLoadLink(mytimeout)
    browser_loaded=0
    i=0
    while (browser_loaded == 0)
      if i<5
        begin
          browser_loaded=1
          Timeout::timeout(mytimeout)  do
            yield
          end
        rescue Timeout::Error => e
          puts "Page load timed out: #{e}"
          browser_loaded=0
          retry
        end
      else
        puts "failed to load resource"
        break
      end
      i+=1
    end
  end
  
  def search_pendingomme(query,stagione,max_results)
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    sureLoadLink(10){ browser.goto 'http://www.pendingomme.it/login' }
               
    puts "page loaded"
    
    fornitore_pendingomme = Fornitore.where(nome: "PendinGomme").first
    browser.text_field(:name => 'email').set fornitore_pendingomme.user_name
                
    browser.text_field(:name => 'passwd').set fornitore_pendingomme.password
               
    browser.button(:name => 'SubmitLogin').click
      
    sleep 1
      
    puts "logged in"
    sureLoadLink(10) { browser.goto('http://www.pendingomme.it/ricerca?controller=search&orderby=position&orderway=desc&search_query='+query.to_s+'&submit_search=') }

    if browser.element(:class => 'alert-warning').present?
      puts "nessun resultato per PendinGomme"
      browser.close
      return
    end
      
    File.open('pages/pendingomme.html', 'w') {|f| f.write browser.ul(:class => 'product_list').html }
   
    puts "closing Watir"
    browser.close
    
    file = File.open('pages/pendingomme.html', 'r')
    document = Nokogiri::HTML(file)
    tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]
    puts tmp
    document.css('ul li').each do |row|
      line = row.css('h5').text.strip
        
      marca = line.split(" ").first
      misura = line.split("(").last.split(")").first[0..-3]
      raggio = line.split("(").last.split(")").first[5..6]
     
      stagione = row.css('p').text.strip.split("Stagione: ").last.split(",").first
      prezzo_netto = row.css(".price").text.strip.gsub(",",".").gsub(" €","").to_f.round(2)
      giacenza = row.css("#pQuantityAvailable").text.strip.split(" ").first.to_i
      
      cod_vel = row.css('p').text.strip.split("LI: ").last.split(",").first + row.css('p').text.strip.split("SI: ").last.split(",").first 
      
       modello = misura[0..2]+"/"+misura[3..-1]+" "+"R"+raggio+" "+marca+" "+line.split(" ").second.strip+" "+cod_vel
      if stagione == "All Season"
        stagione = "4 Stagioni"
      end
      if misura[3]!="/"
        misura = misura[0..2]+"/"+misura[3..-1]
      end
      misura_totale = misura+raggio
     
      if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
        Pneumatico.create(nome_fornitore: "PendinGomme", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @pendingomme, prezzo_netto: prezzo_netto, giacenza: giacenza, stagione: stagione, cod_vel: cod_vel)
      end
        
    end
    file.close
    
  end
  
  def search_farnese(query,stagione,max_results)
    
    marche_pneumatici = {}
    file_pneumatici = File.open('marche_pneumatici.html.erb','r')
    document_pneumatici = Nokogiri::HTML(file_pneumatici)
    document_pneumatici.css('select option').each do |option|
      marche_pneumatici[option["value"]] = option.text
    end
    file_pneumatici.close
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    sureLoadLink(10){ browser.goto 'http://www.b2b.farnesepneus.it/' }
             
    puts "page loaded"
    fornitore_farnese = Fornitore.where(nome: "FarnesePneus").first
    browser.text_field(:name => '_username').set fornitore_farnese.user_name
              
    browser.text_field(:name => '_password').set fornitore_farnese.password
             
    browser.button(:name => '_submit').click
    browser.link(:text =>"Ricerca").click
      
      puts "login effettuato"
      #browser.select_list(:name => 'price-list_length').select 100
    
    element = browser.tr(:class => 'even')
    
    flag = try_until(browser, @farnesepneus, element) {
      browser.select_list(:id => 'season-search').select stagione
      
      browser.text_field(:id => 'fast-search').set query
      #browser.text_field(:id => 'coupled').set query_accoppiata
      
      browser.button(:type => 'submit').click
      
      sleep 5
      
      if browser.td(:class => 'dataTables_empty').present?
        puts "no results for farnese"
        browser.close
        return false
      end
      
      browser.tr(:class => 'even').wait_until_present(timeout: 15)
    }
    puts flag 
    if flag 
      table = browser.table(:id => 'price-list')
      File.open('pages/farnesepneus.html', 'w') {|f| f.write table.html }
   
      puts "closing Watir"
      browser.close
   
      file = File.open('pages/farnesepneus.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]
      puts tmp
      i = 0
      document.css('tbody tr').each do |row|
        if i < max_results
          modello = row.css('.row-description').text.strip.gsub("-","R").gsub("CAM.","").gsub("COP.","")
          misura = modello.split("R",2).first.strip
          marca_tmp = row.css('td.row-manufacturer img').first['src'].split("/").last.split('.').first.to_i.to_s
          marca = marche_pneumatici[marca_tmp]

          raggio = modello.split("R",2).second.split(" ").first
          if row.css('.row-season img').first['src'] != ""
            stagione = row.css('.row-season img').first['src'].split("/").last.split(".").first
          else
            stagione = "Inverno"
          end
          
          if stagione == "summer"
            stagione_db = "Estate"
          elsif stagione == "winter"
            stagione_db = "Inverno"
          else
            stagione_db = "4 Stagioni"
          end
            
          p_netto = row.css('.row-net-price').text.strip.to_f.round(2)
                    
          stock = row.css('.row-stock-column-1').text.strip.to_i + row.css('.row-stock-column-4').text.to_i
          
          misura_totale = misura+raggio
          puts misura_totale
          puts tmp
          if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
            Pneumatico.create(nome_fornitore: "FarnesePneus", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @farnesepneus, prezzo_netto: p_netto, giacenza: stock, stagione: stagione_db)
            i+=1
          end
        end
      end
      file.close
    else
      browser.close
      puts "No results for Farnese"
    end
  end
  
  
  def search_fintyre(query,stagione,max_results)
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    
    sureLoadLink(10){
      browser.goto 'http://b2b.fintyre.it'
    }
    fornitore_fintyre = Fornitore.where(nome: "Fintyre").first
    browser.text_field(:id => 'username').set fornitore_fintyre.user_name
            
    browser.text_field(:id => 'password').set fornitore_fintyre.password
            
           
    browser.button(:id => 'id_submit').click
          
    search_page = 'http://b2b.fintyre.it/fintyre2/main?TASK=Precercaarticoli&OUTPAGE=/ordini/ricerche/ricercaArticoli.jsp&ERRPAGE=/common/error.jsp'  
            
    sureLoadLink(15){ browser.goto search_page}
         
    element = browser.table(:id => 'result')
    
    flag = try_until(browser, search_page , element) {
    
      browser.text_field(:id => 'id_ricerca').set query
      
      #browser.text_field(:id => 'id_ricerca2').set query_accoppiata
      
      if stagione == "Estate"
        id = "Solo estive"
      elsif stagione == "Inverno"
        id = "Solo invernali"
      elsif stagione == "4 Stagioni"
        id = "Solo 4 stagioni"
      end
      
      if stagione != "Tutte"
        browser.select_list(:id => 'id_copertura').select id
      end
      browser.button(:id => 'id_imgRicerca').click
      
      # SE NON DOVESSE FUNZIONARE TORNARE ALL'IMPOSTAZIONE PRECEDENTE CON SLEEP 5 E WAIT SOTTO A NESSUN RISULTATO
      browser.table(:id => 'result').wait_until_present(timeout: 10)
      
      if browser.table(:id => 'result').span(:class => 'infoBanner').present?
        puts "no results for fintyre"
        browser.close
        return false
      end
      
    }
    if flag 
            
      File.open('pages/fintyre.html', 'w') {|f| f.write browser.table(:id => 'result').html }
              
      browser.close
      browser.quit
              
      file = File.open('pages/fintyre.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]
      i = 0
      document.css('tbody tr').each do |row|
        if i<max_results
          marca = row.css('span.logoMarca').text.strip
          cod_vel = row.css("td")[2].text.strip
          puts cod_vel
          modello = row.css('td.descrizione').text.strip+" "+cod_vel
          temp = '#id_listino'+i.to_s
          prezzo_netto = row.css('.netnet').text.to_f.round(2)
          stock = 0
          if row.css('.dispCompleta').present?
            row.css('.dispCompleta').text.split("\n").each do |x|
              stock += x.strip.to_i
            end
          else
            row.css('.dispParziale').text.split("\n").each do |x|
              stock += x.strip.to_i
            end
          end
          misura = modello.split("R").first.strip.gsub("Z","")
          raggio = modello.split("R").second.split(" ").first
          
          if row.css('span.eti._4stagioni').present?
            stagione = "4 Stagioni"
          elsif row.css('span.eti._invernale').present?
            stagione = "Inverno"
          else
            stagione = "Estate"
          end
          
          
          misura_totale = misura+raggio
          
          if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp )
            Pneumatico.create(nome_fornitore: "Fintyre",marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @fintyre, prezzo_netto: prezzo_netto, giacenza: stock, stagione: stagione)
            i+=1
          end
        end
        
      end
      file.close    
    else
      browser.close
      puts "No results for Fintyre"
    end
  end
  
  
  def search_centrogomme(query,stagione,max_results)
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
            
    sureLoadLink(10){ browser.goto 'http://www.centrogomme.com/' }
           
    fornitore_centrogomme = Fornitore.where(nome: "CentroGomme").first
    browser.iframe.text_field(:id => 't_username').set fornitore_centrogomme.user_name
            
    browser.iframe.text_field(:id => 't_pwd').set fornitore_centrogomme.password
           
    browser.iframe.button(:type => 'submit').click
            
    search_page = "http://ordini.centrogomme.com/views/B2BCG/BB.view.php?page=ricerca"
    sureLoadLink(10){ browser.goto search_page }
    element = browser.table(:id => 'searchartico_WT_39019_mt_data')
    
    flag = try_until(browser, search_page, element) {
    
      browser.text_field(:id => 'misura').set query
      
      
      browser.execute_script(%{jQuery("select[name|='stagione']").show();})
      
      browser.select_list(:name => 'stagione').select stagione
              
      
       
      browser.button(:id => 'bottone_cerca').click
      
      sleep 5
      
      
      
      if browser.div(:id => 'tmp_noresult').present?
        puts "no results for centrogomme"
        browser.close
        return false
      end
       
      browser.table(:id => 'searchartico_WT_39019_mt_data').wait_until_present(timeout: 15)
      
      #condition = browser.table(:id => 'searchartico_WT_39019_mt_data').exists? 
      
    }
    puts flag 
    if flag 
            
      File.open('pages/centrogomme.html', 'w') {|f| f.write browser.table(:id => 'searchartico_WT_39019_mt_data').html }
                
      browser.close
      browser.quit
                
      file = File.open('pages/centrogomme.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]        
      
      i = 0
      j = 0
      document.css('tbody tr').each do |row|
        if j<max_results
          
          if row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c2').text.strip.split(" ").first == "CATENE"
            i+=1
            next
          end
          
          marca = row.at_css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c1 img').attr('src').split("/").last[0..-5].gsub("%20"," ").upcase
          nome = row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c2').text.strip
          p_netto = row.at_css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c9').text[4..-1].strip.gsub(",",".").to_f
          stock = row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c10').text.strip.to_i + row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c11').text.strip.to_i + row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c12').text.strip.to_i + row.css('#searchartico_WT_39019_mt_r'+i.to_s+'_searchartico_WT_39019_mt_c13').text.strip.to_i
          puts nome
          tmp_stagione = row.css('img.pdImgstagione').first['src'].split("/").last.split(".").first
          
          if tmp_stagione == "I"
            stagione = "Inverno"
          elsif tmp_stagione == "E"
            stagione = "Estate"
          else
            stagione = "4 Stagioni"
          end
            
         
          if nome[6] != "R" && nome[7] != "R"
            misura = nome.gsub("CAM.", "").split(" ").first.strip
            raggio = nome.gsub("CAM.", "").split(" ").second.strip
          else
          
            misura = nome.gsub("CAM.","").split("R").first.strip
            raggio = nome.gsub("CAM.","").split("R").second.split(" ").first
          end
          
          
          misura_totale = misura+raggio
          
          
          if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp )
            Pneumatico.create(nome_fornitore: "CentroGomme" ,marca: marca, misura: misura, raggio: raggio, modello: nome, fornitore: @centrogomme, prezzo_netto: p_netto, giacenza: stock, stagione: stagione)
            j+=1
          end
        end
        i+=1
      end
      
      file.close   
    else
      browser.close
      puts "No results for CentroGomme"
    end
    
  end
  
  
  def search_multityre(query,stagione,max_results)
    
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
            
    sureLoadLink(10){ browser.goto 'http://multitires.autotua.it/' }
    
    fornitore_multityre = Fornitore.where(nome: "MultiTyre").first
    browser.text_field(:name => 'username').set fornitore_multityre.user_name
            
    browser.text_field(:name => 'password').set fornitore_multityre.password
           
    browser.button(:type => 'submit').click
           
    search_page = 'http://multitires.autotua.it/interna.asp'
    element = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
    
    flag = try_until(browser,search_page,element) {
      browser.iframe.text_field(:class => 'Misura_TextBox').wait_until_present
              
      browser.iframe.text_field(:class => 'Misura_TextBox').set query
      
      if stagione == "Tutte"
        id = "ContenutoPagina_ucRicerca1_cbTutti"
      elsif stagione == "Estate"
        id = "ContenutoPagina_ucRicerca1_cbEstivo"
      elsif stagione == "Inverno"
        id = "ContenutoPagina_ucRicerca1_cbInvernale"
      elsif stagione == "4 Stagioni"
        id = "ContenutoPagina_ucRicerca1_cbQuattroStagioni"
      end
              
     
      browser.iframe.checkbox(:id => id).set
              
      browser.iframe.button(:name => 'ctl00$ContenutoPagina$ucRicerca1$butCercaA').click
      
      sleep 5
      
      
      if browser.iframe(:id => 'search1').span(:class => 'NessunArticolo').text.strip == "Articoli Trovati 0"
        puts "no results for multitires"
        browser.close
        return false
      end
      
      browser.iframe(:id => 'search1').table(:class => 'gvTheGrid').wait_until_present(timeout: 10)
      puts browser.iframe(:id => 'search1').table(:class => 'gvTheGrid').exists?
      
            
      
    }
    puts flag 
    if flag
          
      table = browser.iframe(:id => 'search1').table(:class => 'gvTheGrid')
      File.open('pages/multitires.html', 'w') {|f| f.write table.html }
              
      browser.close
      browser.quit
                
      file = File.open('pages/multitires.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]          
      i = 0
      j = 0
      table = document.css('table.gvTheGrid')
      table.css('tbody tr.Riga').each do |row|
        if i.even? && j<max_results*2
          
          if row.css('td.Catalogo.allinea div').text != ""
            marca = row.css('td.Catalogo.allinea div').text
          else
            marca = row.at_css('td.Catalogo.allinea img').attr("title")
          end
                    
          nome = row.css('div.DescrizioneArticolo').text
          p_netto = row.css('td.CatalogoDisp.ALT.allinea')[1].text.strip.to_f.round(2)
          stock = row.css('td.CatalogoDisp.allinea strong')[0].text.to_i + row.css('td.CatalogoDisp.allinea strong')[1].text.to_i + row.css('td.CatalogoDisp.allinea strong span').text.to_i
          misura = nome.gsub('-','R').split('R',2).first.strip.split(" ").first.strip
          raggio = nome.gsub('-','R').split('R',2).second.split(" ").first.strip
          
          # CONTROLLO SULLA VALIDITA' DEL CAMPO RAGGIO --- DA SISTEMARE PER ALCUNI VALORI
          
          if raggio.to_i.to_s != raggio
            raggio = nome.split(" ")[2]
          end
          
          tmp_stagione = row.css('td.CatalogoDisp.allinea img').first['src'].split("/").last.split(".").first
          
          misura_totale = misura+raggio
          if tmp_stagione == "sun"
            stagione = "Estate"
          elsif tmp_stagione == "snow"
            stagione = "Inverno"
          else
            stagione = "4 Stagioni"
          end
          if (!(Pneumatico.exists?(modello: nome)) && misura_totale == tmp)
            Pneumatico.create(nome_fornitore: "MultiTires", marca: marca, misura: misura, raggio: raggio, modello: nome, fornitore: @multitires, prezzo_netto: p_netto, giacenza: stock, stagione: stagione)
            j+=1
          end
        end 
        i+=1
      end
        
      file.close
    
    else
      browser.close
      puts "no results for multitires"
    end    
  end
  
  def search_maxtyre(query,stagione,max_results)
    switches = ['--load-images=no']
    browser = Watir::Browser.new :phantomjs, :args => switches
    browser.window.maximize
    count = 0
    while true
      begin
        if count>2
          flag = false
          break
        end
          
        sureLoadLink(10){ browser.goto 'http://web.maxtyre.it/' }
                   
        puts "page loaded"
        
        fornitore_maxtyre = Fornitore.where(nome: "MaxTyre").first
        browser.text_field(:name => 'username').set fornitore_maxtyre.user_name
                    
        browser.text_field(:name => 'password').set fornitore_maxtyre.password
                   
        browser.link(:id => 'button-1017').click
          
        sleep 5
        puts "login effettuato"
          
        browser.link(:id =>"button-1026").click
            
        puts "Bottone ricerca premuto" 
          
        browser.text_field(:name => 'codRic').set query
        puts "query settata"
        
       
        index = 0
        browser.links.each do |link|
          if index>20

            if link.text.strip == "Ricerca"
              if stagione == "Tutte"
                link.click
              elsif stagione == "Estate"
                browser.links[index-3].click
              elsif stagione == "Inverno"
                browser.links[index-2].click
              else
                browser.links[index-1].click
              end
            end
          end
          index+=1
        end
  
        puts "sleeeping"
        
        sleep 5 
        if browser.div(:class => 'x-grid-item-container').text.strip == ""
          flag = false
          break
        end
        
        browser.table(:class => 'x-grid-item').wait_until_present(timeout: 20)
        
        if browser.table(:class => 'x-grid-item').present?
          flag = true
          break
        end
      rescue Watir::Exception::UnknownObjectException
        puts "Exception, Retrying"
        count+=1
        retry
      end
    end
    count = 0
    if flag
      table = []
      #max_scrolls = 10
      while true
        if count < 5
          count = table.length
          el = browser.tables(:class => 'x-grid-item').last
          browser.tables(:class => 'x-grid-item').each do |item|
            if !table.include? item
              table.push item
            end
          end
          if count == table.length
            puts "no more results"
            break
          end
          puts "scrolling"
          el.wd.location_once_scrolled_into_view
          sleep 0.25
          count+=1
        else
          break
        end
      end
      
      
     
      
      File.open('pages/maxtyre.html', 'w') {|f| table.each { |e| f.write(e.html) } }
              
      browser.close
      browser.quit
                
      file = File.open('pages/maxtyre.html', 'r')
      document = Nokogiri::HTML(file)
      tmp = query.to_s[0..2]+"/"+query.to_s[3..-1]          
      #table = document.css('table x-grid-item')
      document.css('table.x-grid-item tr').each do |row|
        if row.css('td.x-grid-cell img').first["title"] != ""
          marca = row.css('td.x-grid-cell img').first["title"].split(":").second.strip
        else
          marca = ""
        end
       
        
        modello = row.css("td.x-grid-cell")[1].text
       
        tmp_stagione = row.css("td.x-grid-cell")[10].css("img").first['src'].split("/").last.split(".").first
        if tmp_stagione == "sole"
          stagione = "Estate"
        elsif tmp_stagione == "snow"
          stagione = "Inverno"
        else
          stagione = "4 Stagioni"
        end
        
        prezzo_netto = row.css("td.x-grid-cell")[13].text.strip.to_f.round(2)
     
        
        giacenza = row.css("td.x-grid-cell")[15].text.strip.to_i + row.css("td.x-grid-cell")[16].text.strip.to_i 
        
       
        misura = modello.split(" ").first+"/"+modello.split(" ").second
        raggio = modello.split(" ")[2].gsub(/[^0-9]/, '')
        
        
        
        misura_totale = misura + raggio
        if (!(Pneumatico.exists?(modello: modello)) && misura_totale == tmp)
            Pneumatico.create(nome_fornitore: "MaxTyre", marca: marca, misura: misura, raggio: raggio, modello: modello, fornitore: @maxtyre, prezzo_netto: prezzo_netto, giacenza: giacenza, stagione: stagione)
        end
      end
      file.close
    
    else
      browser.close
      puts "no results for maxtyre"
    end    
  end
    
  def try_until(browser, search_page, element)
    wait = true
    i = 0
    while (wait == true)
    # DA PARAMETRIZZARE PRENDENDO COME ULTERIORE PARAMETRO UN ELEMENTO CHE SI TROVA QUANDO NON CI SONO RISULTATI
      
      if i>4
        return false
      else
        begin
          yield
          if (element.exists?)
            puts "Success"
            #puts element.html
            wait = false
            return true
          end
          
        rescue Selenium::WebDriver::Error::ElementNotDisplayedError
        rescue Selenium::WebDriver::Error::ObsoleteElementError
        rescue Watir::Exception::UnknownObjectException
        rescue Timeout::Error
        rescue Watir::Wait::TimeoutError
        rescue Watir::Exception::UnknownFrameException
        rescue Watir::Exception::UnknownObjectException
          
          puts "Retrying.."
          sleep 1
          sureLoadLink(10){ browser.goto search_page }
        end
      end
      i+=1
    end
  end	
  
end

